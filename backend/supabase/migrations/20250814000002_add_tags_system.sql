-- Phase 2: Tags System Implementation
-- Migration: Add tags and item_tags tables with preset tag seeding

-- Enable required extensions if not already enabled
create extension if not exists pg_trgm;
create extension if not exists pgcrypto;

-- TAGS table
create table if not exists public.tags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null references public.users(id) on delete set null,
  name text not null,
  type text not null default 'custom' check (type in ('preset','custom')),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (user_id, name)
);

-- ITEM_TAGS junction table  
create table if not exists public.item_tags (
  item_id uuid references public.items(id) on delete cascade,
  tag_id uuid references public.tags(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (item_id, tag_id)
);

-- Indexes for performance
create index if not exists idx_tags_user_id on public.tags(user_id);
create index if not exists idx_tags_type on public.tags(type);
create index if not exists idx_tags_name_trgm on public.tags using gin (name gin_trgm_ops);
create index if not exists idx_item_tags_item_id on public.item_tags(item_id);
create index if not exists idx_item_tags_tag_id on public.item_tags(tag_id);

-- Trigger for updated_at on tags
drop trigger if exists trg_tags_updated_at on public.tags;
create trigger trg_tags_updated_at before update on public.tags
for each row execute function public.set_updated_at();

-- Seed preset tags
insert into public.tags (name, type, user_id) values
  ('ai-ml', 'preset', null),
  ('engineering', 'preset', null),
  ('product', 'preset', null),
  ('design', 'preset', null),
  ('startup', 'preset', null),
  ('career', 'preset', null),
  ('health', 'preset', null),
  ('finance', 'preset', null),
  ('read-later', 'preset', null),
  ('watch-later', 'preset', null),
  ('deep-dive', 'preset', null),
  ('quick', 'preset', null),
  ('tutorial', 'preset', null),
  ('reference', 'preset', null),
  ('news', 'preset', null),
  ('longform', 'preset', null),
  ('shortform', 'preset', null),
  ('programming', 'preset', null),
  ('business', 'preset', null),
  ('research', 'preset', null)
on conflict (user_id, name) do nothing;

-- Enhanced views with tag support
create or replace view public.unread_items_with_tags_v as
select 
  i.*,
  coalesce(
    json_agg(
      json_build_object(
        'id', t.id,
        'name', t.name,
        'type', t.type
      ) order by t.name
    ) filter (where t.id is not null),
    '[]'::json
  ) as tags
from public.items i
left join public.item_tags it on i.id = it.item_id
left join public.tags t on it.tag_id = t.id
where i.status = 'unread'
group by i.id
order by i.added_at desc;

create or replace view public.archive_items_with_tags_v as
select 
  i.*,
  coalesce(
    json_agg(
      json_build_object(
        'id', t.id,
        'name', t.name,
        'type', t.type
      ) order by t.name
    ) filter (where t.id is not null),
    '[]'::json
  ) as tags
from public.items i
left join public.item_tags it on i.id = it.item_id
left join public.tags t on it.tag_id = t.id
where i.status = 'completed'
group by i.id
order by i.finished_at desc;

-- Search function for items with tag filtering
create or replace function public.search_items(
  search_query text default '',
  tag_names text[] default '{}',
  content_type_filter text default null,
  status_filter text default 'unread',
  limit_count int default 30,
  offset_count int default 0
)
returns table (
  id uuid,
  user_id uuid,
  url text,
  canonical_url text,
  domain text,
  title text,
  description text,
  image_url text,
  content_type text,
  status text,
  added_at timestamptz,
  finished_at timestamptz,
  source_client text,
  source_platform text,
  notes text,
  metadata jsonb,
  created_at timestamptz,
  updated_at timestamptz,
  tags json
) 
language plpgsql
as $$
begin
  return query
  with filtered_items as (
    select 
      i.*,
      coalesce(
        json_agg(
          json_build_object(
            'id', t.id,
            'name', t.name,
            'type', t.type
          ) order by t.name
        ) filter (where t.id is not null),
        '[]'::json
      ) as item_tags
    from public.items i
    left join public.item_tags it on i.id = it.item_id
    left join public.tags t on it.tag_id = t.id
    where 
      (status_filter is null or i.status = status_filter)
      and (content_type_filter is null or i.content_type = content_type_filter)
      and (
        search_query = '' 
        or i.title ilike '%' || search_query || '%'
        or i.description ilike '%' || search_query || '%'
        or i.domain ilike '%' || search_query || '%'
      )
    group by i.id
  )
  select fi.*
  from filtered_items fi
  where (
    array_length(tag_names, 1) is null
    or exists (
      select 1 
      from public.item_tags it2
      join public.tags t2 on it2.tag_id = t2.id
      where it2.item_id = fi.id
      and t2.name = any(tag_names)
    )
  )
  order by 
    case when status_filter = 'unread' then fi.added_at end desc,
    case when status_filter = 'completed' then fi.finished_at end desc
  limit limit_count
  offset offset_count;
end;
$$;

-- Function to get all tags for a user (including presets)
create or replace function public.get_all_tags(user_id_param uuid default null)
returns table (
  id uuid,
  name text,
  type text,
  usage_count bigint
)
language plpgsql
as $$
begin
  return query
  select 
    t.id,
    t.name,
    t.type,
    count(it.item_id) as usage_count
  from public.tags t
  left join public.item_tags it on t.id = it.tag_id
  where t.user_id is null or t.user_id = user_id_param
  group by t.id, t.name, t.type
  order by t.type, t.name;
end;
$$;

-- Function to add tag to item
create or replace function public.add_tag_to_item(
  item_id_param uuid,
  tag_name_param text,
  user_id_param uuid default null
)
returns uuid
language plpgsql
as $$
declare
  tag_id_result uuid;
begin
  -- Get or create tag
  select id into tag_id_result
  from public.tags
  where name = tag_name_param
  and (user_id is null or user_id = user_id_param);
  
  if tag_id_result is null then
    insert into public.tags (name, type, user_id)
    values (tag_name_param, 'custom', user_id_param)
    returning id into tag_id_result;
  end if;
  
  -- Add tag to item (ignore if already exists)
  insert into public.item_tags (item_id, tag_id)
  values (item_id_param, tag_id_result)
  on conflict (item_id, tag_id) do nothing;
  
  return tag_id_result;
end;
$$;

-- Function to remove tag from item
create or replace function public.remove_tag_from_item(
  item_id_param uuid,
  tag_id_param uuid
)
returns boolean
language plpgsql
as $$
begin
  delete from public.item_tags
  where item_id = item_id_param and tag_id = tag_id_param;
  
  return found;
end;
$$;
