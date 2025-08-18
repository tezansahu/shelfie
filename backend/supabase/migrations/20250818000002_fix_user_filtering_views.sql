-- Fix user filtering in views to ensure proper user isolation
-- This migration updates views to explicitly filter by authenticated user

-- Update unread items view with tags to include user filtering
drop view if exists public.unread_items_with_tags_v;
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
  and i.user_id = auth.uid()
  and i.user_id is not null  -- Exclude items with null user_id
group by i.id
order by i.added_at desc;

-- Update archived items view with tags to include user filtering
drop view if exists public.archive_items_with_tags_v;
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
  and i.user_id = auth.uid()
  and i.user_id is not null  -- Exclude items with null user_id
group by i.id
order by i.finished_at desc;

-- Also update the basic views from the initial schema to include user filtering
drop view if exists public.unread_items_v;
create or replace view public.unread_items_v as
  select * from public.items 
  where status='unread' 
    and user_id = auth.uid() 
    and user_id is not null  -- Exclude items with null user_id
  order by added_at desc;

drop view if exists public.archive_items_v;
create or replace view public.archive_items_v as
  select * from public.items 
  where status='completed' 
    and user_id = auth.uid() 
    and user_id is not null  -- Exclude items with null user_id
  order by finished_at desc;
