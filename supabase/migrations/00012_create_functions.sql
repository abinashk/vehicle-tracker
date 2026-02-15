-- Migration: Create database functions and triggers
-- Description: Auto-matching trigger, updated_at trigger, and supporting functions

-- =============================================================================
-- fn_update_timestamp() - Auto-update updated_at column
-- =============================================================================
CREATE OR REPLACE FUNCTION public.fn_update_timestamp()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_update_timestamp() IS 'Trigger function to automatically set updated_at to current timestamp on row update';

-- Apply updated_at trigger to relevant tables
CREATE TRIGGER trg_parks_updated_at
    BEFORE UPDATE ON public.parks
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_timestamp();

CREATE TRIGGER trg_highway_segments_updated_at
    BEFORE UPDATE ON public.highway_segments
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_timestamp();

CREATE TRIGGER trg_user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_timestamp();

CREATE TRIGGER trg_sync_metadata_updated_at
    BEFORE UPDATE ON public.sync_metadata
    FOR EACH ROW EXECUTE FUNCTION public.fn_update_timestamp();

-- =============================================================================
-- fn_auto_match_passage() - Core matching and violation detection trigger
-- =============================================================================
-- Fires AFTER INSERT on vehicle_passages.
-- Logic:
-- 1. Find an unmatched passage from the OPPOSITE checkpost on the same segment
--    with the same plate_number.
-- 2. Link the two passages (set matched_passage_id on both).
-- 3. Determine which is entry and which is exit (earlier = entry).
-- 4. Calculate travel time and check against segment thresholds.
-- 5. If violation detected, create a violation record.
-- 6. Resolve any proactive overstay alerts for this vehicle/segment.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.fn_auto_match_passage()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_opposite_passage  record;
    v_segment           record;
    v_entry_passage_id  uuid;
    v_exit_passage_id   uuid;
    v_entry_time        timestamptz;
    v_exit_time         timestamptz;
    v_travel_minutes    numeric(8,2);
    v_calculated_speed  numeric(6,2);
    v_violation_type    text;
    v_threshold         numeric(8,2);
BEGIN
    -- Skip if this passage is already matched
    IF NEW.matched_passage_id IS NOT NULL THEN
        RETURN NEW;
    END IF;

    -- Find the most recent unmatched passage from the opposite checkpost
    -- with the same plate number on the same segment.
    -- Use FOR UPDATE to prevent double-matching in concurrent inserts.
    SELECT vp.*
    INTO v_opposite_passage
    FROM public.vehicle_passages vp
    WHERE vp.plate_number = NEW.plate_number
      AND vp.segment_id = NEW.segment_id
      AND vp.checkpost_id <> NEW.checkpost_id
      AND vp.matched_passage_id IS NULL
      AND vp.id <> NEW.id
    ORDER BY vp.recorded_at DESC
    LIMIT 1
    FOR UPDATE OF vp;

    -- No match found, nothing to do
    IF v_opposite_passage IS NULL THEN
        RETURN NEW;
    END IF;

    -- Determine entry (earlier) and exit (later)
    IF NEW.recorded_at >= v_opposite_passage.recorded_at THEN
        v_entry_passage_id := v_opposite_passage.id;
        v_exit_passage_id  := NEW.id;
        v_entry_time       := v_opposite_passage.recorded_at;
        v_exit_time        := NEW.recorded_at;
    ELSE
        v_entry_passage_id := NEW.id;
        v_exit_passage_id  := v_opposite_passage.id;
        v_entry_time       := NEW.recorded_at;
        v_exit_time        := v_opposite_passage.recorded_at;
    END IF;

    -- Link the two passages
    UPDATE public.vehicle_passages
    SET matched_passage_id = NEW.id,
        is_entry = (id = v_entry_passage_id)
    WHERE id = v_opposite_passage.id;

    UPDATE public.vehicle_passages
    SET matched_passage_id = v_opposite_passage.id,
        is_entry = (id = v_entry_passage_id)
    WHERE id = NEW.id;

    -- Get segment details for threshold checking
    SELECT hs.*
    INTO v_segment
    FROM public.highway_segments hs
    WHERE hs.id = NEW.segment_id;

    -- Calculate travel time in minutes
    v_travel_minutes := EXTRACT(EPOCH FROM (v_exit_time - v_entry_time)) / 60.0;

    -- Calculate speed in km/h
    IF v_travel_minutes > 0 THEN
        v_calculated_speed := v_segment.distance_km / (v_travel_minutes / 60.0);
    END IF;

    -- Check for violations
    v_violation_type := NULL;
    v_threshold := NULL;

    IF v_travel_minutes < v_segment.min_travel_time_minutes THEN
        -- Speeding: traveled faster than the maximum allowed speed
        v_violation_type := 'speeding';
        v_threshold := v_segment.min_travel_time_minutes;
    ELSIF v_travel_minutes > v_segment.max_travel_time_minutes THEN
        -- Overstay: traveled slower than the minimum expected speed
        v_violation_type := 'overstay';
        v_threshold := v_segment.max_travel_time_minutes;
    END IF;

    -- Create violation record if threshold was breached
    IF v_violation_type IS NOT NULL THEN
        INSERT INTO public.violations (
            entry_passage_id,
            exit_passage_id,
            segment_id,
            violation_type,
            plate_number,
            vehicle_type,
            entry_time,
            exit_time,
            travel_time_minutes,
            threshold_minutes,
            calculated_speed_kmh,
            speed_limit_kmh,
            distance_km
        ) VALUES (
            v_entry_passage_id,
            v_exit_passage_id,
            NEW.segment_id,
            v_violation_type,
            NEW.plate_number,
            NEW.vehicle_type,
            v_entry_time,
            v_exit_time,
            v_travel_minutes,
            v_threshold,
            v_calculated_speed,
            v_segment.max_speed_kmh,
            v_segment.distance_km
        );
    END IF;

    -- Resolve any proactive overstay alerts for this vehicle on this segment
    UPDATE public.proactive_overstay_alerts
    SET resolved = true,
        resolved_at = now(),
        resolved_by_passage_id = v_exit_passage_id
    WHERE plate_number = NEW.plate_number
      AND segment_id = NEW.segment_id
      AND resolved = false;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_auto_match_passage() IS 'Trigger function that fires after inserting a vehicle passage. Finds and links matching passage from opposite checkpost, detects violations, and resolves overstay alerts.';

-- Apply auto-match trigger to vehicle_passages
CREATE TRIGGER trg_vehicle_passages_auto_match
    AFTER INSERT ON public.vehicle_passages
    FOR EACH ROW EXECUTE FUNCTION public.fn_auto_match_passage();
