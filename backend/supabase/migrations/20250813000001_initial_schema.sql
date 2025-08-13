-- Enable extensions
create extension if not exists pg_trgm;
create extension if not exists pgcrypto;

-- USERS table (placeholder for future SSO)
create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  email text unique null,
  display_name text null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ITEMS table (saved pages/videos)
create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null references public.users(id) on delete set null,
  url text not null,
  canonical_url text null,
  domain text not null,
  title text null,
  description text null,
  image_url text null,
  content_type text not null check (content_type in ('article','video')),
  status text not null default 'unread' check (status in ('unread','completed')),
  added_at timestamptz not null default now(),
  finished_at timestamptz null,
  source_client text not null default 'unknown',
  source_platform text null,
  notes text null,
  metadata jsonb not null default '{}',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- TAGS table (for Phase 2)
create table if not exists public.tags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null references public.users(id) on delete set null,
  name text not null,
  type text not null default 'custom' check (type in ('preset','custom')),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (user_id, name)
);

-- ITEM_TAGS table (many-to-many, for Phase 2)
create table if not exists public.item_tags (
  item_id uuid references public.items(id) on delete cascade,
  tag_id uuid references public.tags(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (item_id, tag_id)
);

-- EVENTS table (for analytics, Phase 3)
create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  item_id uuid references public.items(id) on delete cascade,
  event_type text not null check (event_type in ('added','completed','deleted','tag_added','tag_removed')),
  at timestamptz not null default now(),
  metadata jsonb not null default '{}'
);

-- INDEXES
create index if not exists idx_items_status on public.items(status);
create index if not exists idx_items_added_at on public.items(added_at desc);
create index if not exists idx_items_finished_at on public.items(finished_at desc);
create index if not exists idx_items_domain on public.items(domain);
create index if not exists idx_items_title_trgm on public.items using gin (title gin_trgm_ops);
create unique index if not exists idx_items_canonical_unique on public.items (coalesce(canonical_url, url));

-- VIEWS
create or replace view public.unread_items_v as
  select * from public.items where status='unread' order by added_at desc;

create or replace view public.archive_items_v as
  select * from public.items where status='completed' order by finished_at desc;

-- TRIGGERS
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin 
  new.updated_at = now(); 
  return new; 
end $$;

create trigger trg_items_updated_at before update on public.items
for each row execute function public.set_updated_at();

create trigger trg_users_updated_at before update on public.users
for each row execute function public.set_updated_at();

create trigger trg_tags_updated_at before update on public.tags
for each row execute function public.set_updated_at();

-- Status change trigger to manage finished_at
create or replace function public.items_status_finished_at()
returns trigger language plpgsql as $$
begin
  if new.status='completed' and (old.status is distinct from 'completed') then
    new.finished_at := coalesce(new.finished_at, now());
  elsif new.status='unread' and old.status='completed' then
    new.finished_at := null;
  end if;
  return new;
end $$;

create trigger trg_items_status_finished before update on public.items
for each row execute function public.items_status_finished_at();

-- Event logging trigger for analytics
create or replace function public.items_events()
returns trigger language plpgsql as $$
begin
  if TG_OP = 'INSERT' then
    insert into public.events (item_id, event_type, metadata)
    values (new.id, 'added', jsonb_build_object('source_client', new.source_client, 'source_platform', new.source_platform));
    return new;
  elsif TG_OP = 'UPDATE' and old.status != new.status and new.status = 'completed' then
    insert into public.events (item_id, event_type, metadata)
    values (new.id, 'completed', jsonb_build_object('previous_status', old.status));
    return new;
  elsif TG_OP = 'DELETE' then
    insert into public.events (item_id, event_type, metadata)
    values (old.id, 'deleted', jsonb_build_object('status', old.status));
    return old;
  end if;
  return coalesce(new, old);
end $$;

create trigger trg_items_events
  after insert or update or delete on public.items
  for each row execute function public.items_events();

-- Content type enforcement based on domain
create or replace function public.items_enforce_content_type()
returns trigger language plpgsql as $$
begin
  if new.domain in ('youtube.com', 'youtu.be', 'vimeo.com') then
    new.content_type := 'video';
  elsif new.content_type is null then
    new.content_type := 'article';
  end if;
  return new;
end $$;

create trigger trg_items_content_type before insert or update on public.items
for each row execute function public.items_enforce_content_type();

-- RLS Policies (disabled for Phase 1 MVP, prepare for future)
-- alter table public.items enable row level security;
-- alter table public.tags enable row level security;
-- alter table public.item_tags enable row level security;

-- Policy for single user (Phase 1)
-- create policy "Allow all operations for Phase 1" on public.items for all to anon using (true);
-- create policy "Allow all operations for Phase 1" on public.tags for all to anon using (true);
-- create policy "Allow all operations for Phase 1" on public.item_tags for all to anon using (true);
