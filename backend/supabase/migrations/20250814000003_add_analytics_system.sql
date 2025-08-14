-- Phase 3: Analytics System Implementation
-- Migration: Add events table and analytics_summary() RPC function

-- EVENTS table for analytics tracking
create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  item_id uuid references public.items(id) on delete cascade,
  event_type text not null check (event_type in ('added','completed','deleted','tag_added','tag_removed')),
  at timestamptz not null default now(),
  metadata jsonb not null default '{}',
  created_at timestamptz default now()
);

-- Indexes for performance
create index if not exists idx_events_item_id on public.events(item_id);
create index if not exists idx_events_type on public.events(event_type);
create index if not exists idx_events_at on public.events(at desc);
create index if not exists idx_events_type_at on public.events(event_type, at desc);

-- Trigger to automatically log events on item changes
create or replace function public.log_item_events()
returns trigger language plpgsql as $$
begin
  -- Log 'added' event on insert
  if TG_OP = 'INSERT' then
    insert into public.events (item_id, event_type, at, metadata)
    values (NEW.id, 'added', NEW.added_at, json_build_object(
      'source_client', NEW.source_client,
      'source_platform', NEW.source_platform,
      'content_type', NEW.content_type,
      'domain', NEW.domain
    ));
    return NEW;
  end if;

  -- Log 'completed' event on status change to completed
  if TG_OP = 'UPDATE' and OLD.status != 'completed' and NEW.status = 'completed' then
    insert into public.events (item_id, event_type, at, metadata)
    values (NEW.id, 'completed', coalesce(NEW.finished_at, now()), json_build_object(
      'content_type', NEW.content_type,
      'domain', NEW.domain,
      'time_to_complete_hours', extract(epoch from (coalesce(NEW.finished_at, now()) - NEW.added_at)) / 3600
    ));
    return NEW;
  end if;

  -- Log 'deleted' event on delete
  if TG_OP = 'DELETE' then
    insert into public.events (item_id, event_type, at, metadata)
    values (OLD.id, 'deleted', now(), json_build_object(
      'status', OLD.status,
      'content_type', OLD.content_type,
      'domain', OLD.domain,
      'was_completed', OLD.status = 'completed'
    ));
    return OLD;
  end if;

  return NEW;
end $$;

-- Create triggers for event logging
drop trigger if exists trg_items_events on public.items;
create trigger trg_items_events
  after insert or update or delete on public.items
  for each row execute function public.log_item_events();

-- Trigger to log tag events
create or replace function public.log_tag_events()
returns trigger language plpgsql as $$
begin
  if TG_OP = 'INSERT' then
    insert into public.events (item_id, event_type, at, metadata)
    select NEW.item_id, 'tag_added', now(), json_build_object(
      'tag_id', NEW.tag_id,
      'tag_name', t.name,
      'tag_type', t.type
    )
    from public.tags t where t.id = NEW.tag_id;
    return NEW;
  end if;

  if TG_OP = 'DELETE' then
    insert into public.events (item_id, event_type, at, metadata)
    select OLD.item_id, 'tag_removed', now(), json_build_object(
      'tag_id', OLD.tag_id,
      'tag_name', t.name,
      'tag_type', t.type
    )
    from public.tags t where t.id = OLD.tag_id;
    return OLD;
  end if;

  return NEW;
end $$;

drop trigger if exists trg_item_tags_events on public.item_tags;
create trigger trg_item_tags_events
  after insert or delete on public.item_tags
  for each row execute function public.log_tag_events();

-- Analytics summary RPC function (Enhanced with all features)
CREATE OR REPLACE FUNCTION public.analytics_summary(
  since timestamptz DEFAULT now() - interval '90 days'
) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  result jsonb;
  pending_total integer;
  pending_reading integer;
  pending_viewing integer;
  completed_7d integer;
  completed_30d integer;
  completed_period integer;
  added_period integer;
  completed_from_period integer;
  avg_hours numeric;
  median_hours numeric;
  completion_rate numeric;
  backlog_data json;
  weekly_data json;
  domains_data json;
  tags_data json;
  current_streak integer;
BEGIN
  -- Calculate basic metrics
  SELECT 
    count(*) FILTER (WHERE status = 'unread'),
    count(*) FILTER (WHERE status = 'unread' AND content_type = 'article'),
    count(*) FILTER (WHERE status = 'unread' AND content_type = 'video'),
    count(*) FILTER (WHERE status = 'completed' AND finished_at >= now() - interval '7 days'),
    count(*) FILTER (WHERE status = 'completed' AND finished_at >= now() - interval '30 days'),
    count(*) FILTER (WHERE status = 'completed' AND finished_at >= since),
    count(*) FILTER (WHERE added_at >= since),
    count(*) FILTER (WHERE status = 'completed' AND added_at >= since),
    avg(extract(epoch from (finished_at - added_at)) / 3600) FILTER (WHERE status = 'completed' AND finished_at >= since),
    percentile_cont(0.5) within group (order by extract(epoch from (finished_at - added_at)) / 3600) FILTER (WHERE status = 'completed' AND finished_at >= since)
  INTO pending_total, pending_reading, pending_viewing, completed_7d, completed_30d, completed_period, added_period, completed_from_period, avg_hours, median_hours
  FROM public.items;
  
  completion_rate := CASE WHEN added_period > 0 THEN round((completed_from_period::decimal / added_period) * 100, 1) ELSE 0 END;
  
  -- Get backlog age distribution (FIXED - proper ordering)
  WITH age_buckets AS (
    SELECT
      CASE
        WHEN days_old <= 7 THEN '0-7 days'
        WHEN days_old <= 30 THEN '8-30 days'
        WHEN days_old <= 90 THEN '31-90 days'
        WHEN days_old <= 180 THEN '91-180 days'
        ELSE '180+ days'
      END as age_bucket,
      count(*)::integer as item_count,
      CASE
        WHEN days_old <= 7 THEN 1
        WHEN days_old <= 30 THEN 2
        WHEN days_old <= 90 THEN 3
        WHEN days_old <= 180 THEN 4
        ELSE 5
      END as sort_order
    FROM (
      SELECT extract(epoch from (now() - added_at)) / 86400 as days_old
      FROM public.items
      WHERE status = 'unread'
    ) age_calc
    GROUP BY (
      CASE
        WHEN days_old <= 7 THEN '0-7 days'
        WHEN days_old <= 30 THEN '8-30 days'
        WHEN days_old <= 90 THEN '31-90 days'
        WHEN days_old <= 180 THEN '91-180 days'
        ELSE '180+ days'
      END
    ), (
      CASE
        WHEN days_old <= 7 THEN 1
        WHEN days_old <= 30 THEN 2
        WHEN days_old <= 90 THEN 3
        WHEN days_old <= 180 THEN 4
        ELSE 5
      END
    )
  )
  SELECT json_agg(json_build_object(
    'age_bucket', age_bucket,
    'count', item_count
  ) ORDER BY sort_order) INTO backlog_data
  FROM age_buckets;
  
  -- Get weekly completions
  SELECT json_agg(json_build_object(
    'week', to_char(week_start, 'YYYY-MM-DD'),
    'week_number', extract(week from week_start)::integer,
    'year', extract(year from week_start)::integer,
    'added', 0,
    'completed', COALESCE(completed_count, 0)
  )) INTO weekly_data
  FROM (
    SELECT 
      week_start,
      completed_count
    FROM generate_series(
      date_trunc('week', now() - interval '11 weeks'),
      date_trunc('week', now()),
      interval '1 week'
    ) as week_start
    LEFT JOIN (
      SELECT
        date_trunc('week', finished_at) as week,
        count(*)::integer as completed_count
      FROM public.items
      WHERE finished_at >= (now() - interval '11 weeks')
        AND status = 'completed'
      GROUP BY date_trunc('week', finished_at)
    ) weekly_completed ON week_start = weekly_completed.week
    ORDER BY week_start
  ) weekly_summary;
  
  -- Get top domains
  SELECT json_agg(json_build_object(
    'domain', domain,
    'total_count', total_count,
    'completed_count', completed_count
  )) INTO domains_data
  FROM (
    SELECT
      domain,
      count(*)::integer as total_count,
      count(*) FILTER (WHERE status = 'completed')::integer as completed_count
    FROM public.items
    WHERE added_at >= since
    GROUP BY domain
    ORDER BY count(*) DESC
    LIMIT 10
  ) domain_summary;
  
  -- Get top tags (only if tables exist and have data)
  SELECT json_agg(json_build_object(
    'name', name,
    'type', type,
    'completed_count', completed_count
  )) INTO tags_data
  FROM (
    SELECT
      t.name,
      t.type,
      count(*)::integer as completed_count
    FROM public.items i
    JOIN public.item_tags it ON i.id = it.item_id
    JOIN public.tags t ON it.tag_id = t.id
    WHERE i.status = 'completed' 
      AND i.finished_at >= since
    GROUP BY t.id, t.name, t.type
    ORDER BY count(*) DESC
    LIMIT 10
  ) tags_summary;
  
  -- Calculate simple streak (consecutive days with completions in last 30 days)
  SELECT COALESCE(max_consecutive, 0) INTO current_streak
  FROM (
    SELECT 
      max(consecutive_days) as max_consecutive
    FROM (
      SELECT 
        completion_date,
        count(*) OVER (
          PARTITION BY grp 
          ORDER BY completion_date
        ) as consecutive_days
      FROM (
        SELECT 
          completion_date,
          completion_date - (row_number() OVER (ORDER BY completion_date))::integer * interval '1 day' as grp
        FROM (
          SELECT DISTINCT date_trunc('day', finished_at)::date as completion_date
          FROM public.items
          WHERE status = 'completed'
            AND finished_at >= now() - interval '30 days'
          ORDER BY completion_date DESC
        ) daily_completions
      ) grouped
    ) streaks
  ) streak_calc;
  
  -- Build final result
  result := json_build_object(
    'metrics', json_build_object(
      'pending_total', pending_total,
      'pending_reading', pending_reading,
      'pending_viewing', pending_viewing,
      'completed_7d', completed_7d,
      'completed_30d', completed_30d,
      'completed_period', completed_period,
      'completion_rate', completion_rate,
      'avg_hours_to_complete', CASE WHEN avg_hours IS NOT NULL THEN round(avg_hours, 1) ELSE null END,
      'median_hours_to_complete', CASE WHEN median_hours IS NOT NULL THEN round(median_hours, 1) ELSE null END
    ),
    'charts', json_build_object(
      'weekly_completions', COALESCE(weekly_data, '[]'::json),
      'top_tags', COALESCE(tags_data, '[]'::json),
      'top_domains', COALESCE(domains_data, '[]'::json),
      'backlog_age', COALESCE(backlog_data, '[]'::json)
    ),
    'streaks', json_build_object(
      'current_streak', current_streak
    )
  );
  
  RETURN result;
END $$;

-- Grant necessary permissions
grant execute on function public.analytics_summary to anon;
grant execute on function public.analytics_summary to authenticated;

-- Backfill events for existing items (optional, for demo data)
-- This creates historical events based on existing items
insert into public.events (item_id, event_type, at, metadata)
select 
  id,
  'added',
  added_at,
  json_build_object(
    'source_client', source_client,
    'source_platform', source_platform,
    'content_type', content_type,
    'domain', domain,
    'backfilled', true
  )
from public.items
where not exists (
  select 1 from public.events e 
  where e.item_id = items.id and e.event_type = 'added'
)
on conflict do nothing;

-- Backfill completed events
insert into public.events (item_id, event_type, at, metadata)
select 
  id,
  'completed',
  coalesce(finished_at, updated_at),
  json_build_object(
    'content_type', content_type,
    'domain', domain,
    'time_to_complete_hours', extract(epoch from (coalesce(finished_at, updated_at) - added_at)) / 3600,
    'backfilled', true
  )
from public.items
where status = 'completed'
and not exists (
  select 1 from public.events e 
  where e.item_id = items.id and e.event_type = 'completed'
)
on conflict do nothing;

-- Backfill tag events for existing item-tag relationships
insert into public.events (item_id, event_type, at, metadata)
select 
  it.item_id,
  'tag_added',
  it.created_at,
  json_build_object(
    'tag_id', it.tag_id,
    'tag_name', t.name,
    'tag_type', t.type,
    'backfilled', true
  )
from public.item_tags it
join public.tags t on it.tag_id = t.id
where not exists (
  select 1 from public.events e 
  where e.item_id = it.item_id 
  and e.event_type = 'tag_added'
  and (e.metadata->>'tag_id')::uuid = it.tag_id
)
on conflict do nothing;

-- Comment: Analytics system is now ready
-- The events table will automatically track future actions
-- The analytics_summary() function provides comprehensive metrics and chart data
-- Call: SELECT analytics_summary() or SELECT analytics_summary('2025-01-01'::timestamptz)
