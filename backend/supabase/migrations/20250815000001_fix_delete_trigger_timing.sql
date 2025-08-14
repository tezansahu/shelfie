-- Fix delete trigger timing issue
-- The previous trigger was trying to log delete events AFTER deletion,
-- which caused foreign key constraint violations since the item was already deleted

-- Drop the existing trigger
drop trigger if exists trg_items_events on public.items;

-- Recreate the trigger function to handle delete events properly
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

  -- Log 'deleted' event on delete (OLD record since it's BEFORE delete)
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

-- Create the trigger with proper timing:
-- - AFTER for INSERT and UPDATE (so we have the final state)
-- - BEFORE for DELETE (so the item still exists when we log the event)
create trigger trg_items_events_insert_update
  after insert or update on public.items
  for each row execute function public.log_item_events();

create trigger trg_items_events_delete
  before delete on public.items
  for each row execute function public.log_item_events();
