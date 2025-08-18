-- Fix analytics function to respect user authentication and RLS
-- This migration updates the analytics_summary function to filter by authenticated user

-- Drop the existing function
DROP FUNCTION IF EXISTS public.analytics_summary(timestamptz);

-- Create the user-aware analytics function
CREATE OR REPLACE FUNCTION public.analytics_summary(
  since timestamptz DEFAULT now() - interval '90 days'
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  result jsonb;
  current_user_id uuid;
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
  -- Get the current authenticated user
  current_user_id := auth.uid();
  
  -- Ensure user is authenticated
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to access analytics';
  END IF;

  -- Calculate basic metrics (filtered by user_id)
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
  FROM public.items
  WHERE user_id = current_user_id;
  
  completion_rate := CASE WHEN added_period > 0 THEN round((completed_from_period::decimal / added_period) * 100, 1) ELSE 0 END;
  
  -- Get backlog age distribution (filtered by user_id)
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
        AND user_id = current_user_id
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
  
  -- Get weekly completions (filtered by user_id)
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
        AND user_id = current_user_id
      GROUP BY date_trunc('week', finished_at)
    ) weekly_completed ON week_start = weekly_completed.week
    ORDER BY week_start
  ) weekly_summary;
  
  -- Get top domains (filtered by user_id)
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
      AND user_id = current_user_id
    GROUP BY domain
    ORDER BY count(*) DESC
    LIMIT 10
  ) domain_summary;
  
  -- Get top tags (filtered by user_id)
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
      AND i.user_id = current_user_id
      AND t.user_id = current_user_id
    GROUP BY t.name, t.type
    ORDER BY count(*) DESC
    LIMIT 10
  ) tag_summary;
  
  -- Calculate current reading streak (filtered by user_id)
  WITH daily_completions AS (
    SELECT 
      date_trunc('day', finished_at) as completion_date,
      count(*) as completions
    FROM public.items
    WHERE status = 'completed'
      AND finished_at >= now() - interval '90 days'
      AND user_id = current_user_id
    GROUP BY date_trunc('day', finished_at)
    ORDER BY completion_date DESC
  ),
  streak_calculation AS (
    SELECT 
      completion_date,
      completions,
      row_number() over (order by completion_date desc) as day_number,
      (current_date - completion_date::date) as days_ago
    FROM daily_completions
  )
  SELECT count(*) INTO current_streak
  FROM streak_calculation
  WHERE days_ago = day_number - 1;
  
  -- Build final result
  result := json_build_object(
    'metrics', json_build_object(
      'pending_total', COALESCE(pending_total, 0),
      'pending_reading', COALESCE(pending_reading, 0), 
      'pending_viewing', COALESCE(pending_viewing, 0),
      'completed_7d', COALESCE(completed_7d, 0),
      'completed_30d', COALESCE(completed_30d, 0),
      'completed_period', COALESCE(completed_period, 0),
      'completion_rate', COALESCE(completion_rate, 0),
      'avg_hours_to_complete', avg_hours,
      'median_hours_to_complete', median_hours
    ),
    'charts', json_build_object(
      'weekly_completions', COALESCE(weekly_data, '[]'::json),
      'top_domains', COALESCE(domains_data, '[]'::json),
      'top_tags', COALESCE(tags_data, '[]'::json),
      'backlog_age', COALESCE(backlog_data, '[]'::json)
    ),
    'streaks', json_build_object(
      'current_streak', COALESCE(current_streak, 0)
    )
  );
  
  RETURN result;
END $$;

-- Grant permissions to authenticated users only (remove anon access)
REVOKE ALL ON FUNCTION public.analytics_summary(timestamptz) FROM anon;
GRANT EXECUTE ON FUNCTION public.analytics_summary(timestamptz) TO authenticated;
