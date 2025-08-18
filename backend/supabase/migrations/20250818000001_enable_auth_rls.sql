-- Enable Google Auth and user management for Shelfie
-- This migration enables Google SSO authentication and sets up RLS policies

-- First, enable RLS on all tables
alter table public.users enable row level security;
alter table public.items enable row level security;
alter table public.tags enable row level security;
alter table public.item_tags enable row level security;
alter table public.events enable row level security;

-- Update users table to be populated by Supabase Auth
alter table public.users alter column email set not null;

-- Create a function to handle new user creation from auth.users
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.users (id, email, display_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)));
  return new;
end $$;

-- Create trigger to automatically create user profile on auth signup
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- RLS Policies for users table
drop policy if exists "Users can view own profile" on public.users;
create policy "Users can view own profile" on public.users
  for select using (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.users;
create policy "Users can update own profile" on public.users
  for update using (auth.uid() = id);

-- RLS Policies for items table  
drop policy if exists "Users can view own items" on public.items;
create policy "Users can view own items" on public.items
  for select using (auth.uid() = user_id);

drop policy if exists "Users can insert own items" on public.items;
create policy "Users can insert own items" on public.items
  for insert with check (auth.uid() = user_id);

drop policy if exists "Users can update own items" on public.items;
create policy "Users can update own items" on public.items
  for update using (auth.uid() = user_id);

drop policy if exists "Users can delete own items" on public.items;
create policy "Users can delete own items" on public.items
  for delete using (auth.uid() = user_id);

-- RLS Policies for tags table
drop policy if exists "Users can view own tags" on public.tags;
create policy "Users can view own tags" on public.tags
  for select using (auth.uid() = user_id);

drop policy if exists "Users can insert own tags" on public.tags;
create policy "Users can insert own tags" on public.tags
  for insert with check (auth.uid() = user_id);

drop policy if exists "Users can update own tags" on public.tags;
create policy "Users can update own tags" on public.tags
  for update using (auth.uid() = user_id);

drop policy if exists "Users can delete own tags" on public.tags;
create policy "Users can delete own tags" on public.tags
  for delete using (auth.uid() = user_id);

-- RLS Policies for item_tags table
drop policy if exists "Users can view own item tags" on public.item_tags;
create policy "Users can view own item tags" on public.item_tags
  for select using (
    exists (
      select 1 from public.items 
      where id = item_id and user_id = auth.uid()
    )
  );

drop policy if exists "Users can insert own item tags" on public.item_tags;
create policy "Users can insert own item tags" on public.item_tags
  for insert with check (
    exists (
      select 1 from public.items 
      where id = item_id and user_id = auth.uid()
    )
  );

drop policy if exists "Users can delete own item tags" on public.item_tags;
create policy "Users can delete own item tags" on public.item_tags
  for delete using (
    exists (
      select 1 from public.items 
      where id = item_id and user_id = auth.uid()
    )
  );

-- RLS Policies for events table  
drop policy if exists "Users can view own events" on public.events;
create policy "Users can view own events" on public.events
  for select using (
    exists (
      select 1 from public.items 
      where id = item_id and user_id = auth.uid()
    )
  );

drop policy if exists "System can insert events" on public.events;
create policy "System can insert events" on public.events
  for insert with check (true); -- Allow system triggers to insert events

-- Update views to include user filtering
drop view if exists public.unread_items_v;
create or replace view public.unread_items_v as
  select * from public.items 
  where status='unread' and user_id = auth.uid() 
  order by added_at desc;

drop view if exists public.archive_items_v;
create or replace view public.archive_items_v as
  select * from public.items 
  where status='completed' and user_id = auth.uid() 
  order by finished_at desc;

-- Create a function to get current user ID (for use in functions)
create or replace function public.get_current_user_id()
returns uuid language sql security definer as $$
  select auth.uid();
$$;

-- Update existing functions to enforce user isolation
-- This ensures Edge Functions also respect user boundaries
create or replace function public.items_enforce_user_id()
returns trigger language plpgsql as $$
begin
  -- For authenticated users, set user_id to current user
  if auth.uid() is not null then
    new.user_id := auth.uid();
  else
    -- Reject insert if no authenticated user
    raise exception 'Authentication required to save items';
  end if;
  return new;
end $$;

-- Create trigger to enforce user_id on insert
drop trigger if exists trg_items_enforce_user_id on public.items;
create trigger trg_items_enforce_user_id before insert on public.items
  for each row execute function public.items_enforce_user_id();

-- Similar function for tags
create or replace function public.tags_enforce_user_id()
returns trigger language plpgsql as $$
begin
  -- For authenticated users, set user_id to current user
  if auth.uid() is not null then
    new.user_id := auth.uid();
  else
    -- Reject insert if no authenticated user
    raise exception 'Authentication required to create tags';
  end if;
  return new;
end $$;

-- Create trigger to enforce user_id on insert for tags
drop trigger if exists trg_tags_enforce_user_id on public.tags;
create trigger trg_tags_enforce_user_id before insert on public.tags
  for each row execute function public.tags_enforce_user_id();
