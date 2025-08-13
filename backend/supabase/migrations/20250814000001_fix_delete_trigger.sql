-- Fix the delete trigger issue by changing the trigger timing
-- The DELETE event should be logged BEFORE the item is actually deleted

-- Drop the existing trigger
DROP TRIGGER IF EXISTS trg_items_events ON public.items;

-- Recreate the trigger with BEFORE DELETE for the delete event
CREATE OR REPLACE FUNCTION public.items_events()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.events (item_id, event_type, metadata)
    VALUES (NEW.id, 'added', jsonb_build_object('source_client', NEW.source_client, 'source_platform', NEW.source_platform));
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' AND OLD.status != NEW.status AND NEW.status = 'completed' THEN
    INSERT INTO public.events (item_id, event_type, metadata)
    VALUES (NEW.id, 'completed', jsonb_build_object('previous_status', OLD.status));
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    -- Log the delete event BEFORE the item is actually deleted
    INSERT INTO public.events (item_id, event_type, metadata)
    VALUES (OLD.id, 'deleted', jsonb_build_object('status', OLD.status));
    RETURN OLD;
  END IF;
  RETURN COALESCE(NEW, OLD);
END $$;

-- Create separate triggers with appropriate timing
CREATE TRIGGER trg_items_events_before_delete
  BEFORE DELETE ON public.items
  FOR EACH ROW EXECUTE FUNCTION public.items_events();

CREATE TRIGGER trg_items_events_after_insert_update
  AFTER INSERT OR UPDATE ON public.items
  FOR EACH ROW EXECUTE FUNCTION public.items_events();
