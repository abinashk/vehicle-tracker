-- Migration: Backend review fixes
-- Addresses critical issues found during PR #2 review:
-- 1. UNIQUE constraint on proactive_overstay_alerts.entry_passage_id
-- 2. fn_match_passages RPC for atomic passage matching with row locking
-- 3. find_overdue_unmatched_passages RPC for check-overstay function

-- =============================================================================
-- Fix #2: Add UNIQUE constraint on proactive_overstay_alerts.entry_passage_id
-- Prevents duplicate alerts for the same entry passage.
-- First deduplicate any existing rows (keep most recent per entry_passage_id).
-- =============================================================================
DELETE FROM public.proactive_overstay_alerts
WHERE id IN (
    SELECT id FROM (
        SELECT id,
               ROW_NUMBER() OVER (
                   PARTITION BY entry_passage_id
                   ORDER BY created_at DESC
               ) AS rn
        FROM public.proactive_overstay_alerts
    ) ranked
    WHERE ranked.rn > 1
);

ALTER TABLE public.proactive_overstay_alerts
    ADD CONSTRAINT uq_overstay_alerts_entry_passage_id
    UNIQUE (entry_passage_id);

-- =============================================================================
-- Fix #4/#5: fn_match_passages - Atomic passage matching with SELECT FOR UPDATE
-- Used by match-passage edge function to prevent TOCTOU race conditions.
-- Locks both passage rows, verifies they're unmatched, then links them.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.fn_match_passages(
    p_entry_id uuid,
    p_exit_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_entry record;
    v_exit  record;
BEGIN
    -- Lock both rows with FOR UPDATE to prevent concurrent matching.
    -- Order by id to prevent deadlocks (consistent lock ordering).
    IF p_entry_id < p_exit_id THEN
        SELECT * INTO v_entry FROM vehicle_passages WHERE id = p_entry_id FOR UPDATE;
        SELECT * INTO v_exit  FROM vehicle_passages WHERE id = p_exit_id  FOR UPDATE;
    ELSE
        SELECT * INTO v_exit  FROM vehicle_passages WHERE id = p_exit_id  FOR UPDATE;
        SELECT * INTO v_entry FROM vehicle_passages WHERE id = p_entry_id FOR UPDATE;
    END IF;

    -- Verify both passages exist
    IF v_entry IS NULL THEN
        RAISE EXCEPTION 'Entry passage % not found', p_entry_id;
    END IF;
    IF v_exit IS NULL THEN
        RAISE EXCEPTION 'Exit passage % not found', p_exit_id;
    END IF;

    -- Verify neither is already matched
    IF v_entry.matched_passage_id IS NOT NULL THEN
        RAISE EXCEPTION 'Entry passage % is already matched', p_entry_id;
    END IF;
    IF v_exit.matched_passage_id IS NOT NULL THEN
        RAISE EXCEPTION 'Exit passage % is already matched', p_exit_id;
    END IF;

    -- Link entry → exit
    UPDATE vehicle_passages
    SET matched_passage_id = p_exit_id,
        is_entry = true
    WHERE id = p_entry_id;

    -- Link exit → entry
    UPDATE vehicle_passages
    SET matched_passage_id = p_entry_id,
        is_entry = false
    WHERE id = p_exit_id;
END;
$$;

COMMENT ON FUNCTION public.fn_match_passages(uuid, uuid) IS 'Atomically match two passages with row-level locking to prevent race conditions. Raises exception if either passage is already matched.';

-- =============================================================================
-- Fix #4: find_overdue_unmatched_passages - Used by check-overstay function
-- Returns unmatched entry passages past max_travel_time that don't already
-- have a proactive_overstay_alert.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.find_overdue_unmatched_passages()
RETURNS TABLE (
    id uuid,
    plate_number text,
    vehicle_type text,
    recorded_at timestamptz,
    segment_id uuid,
    max_travel_time_minutes numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        vp.id,
        vp.plate_number,
        vp.vehicle_type,
        vp.recorded_at,
        vp.segment_id,
        hs.max_travel_time_minutes
    FROM vehicle_passages vp
    INNER JOIN highway_segments hs ON hs.id = vp.segment_id
    LEFT JOIN proactive_overstay_alerts poa ON poa.entry_passage_id = vp.id
    WHERE vp.matched_passage_id IS NULL
      AND poa.id IS NULL
      AND vp.recorded_at + (hs.max_travel_time_minutes || ' minutes')::interval < now()
    ORDER BY vp.recorded_at ASC;
$$;

COMMENT ON FUNCTION public.find_overdue_unmatched_passages() IS 'Returns unmatched vehicle passages that have exceeded their segment max travel time and do not yet have a proactive overstay alert.';

-- =============================================================================
-- Grant execute permissions to service_role for both new functions.
-- Edge functions call these via service role client.
-- =============================================================================
GRANT EXECUTE ON FUNCTION public.fn_match_passages(uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.find_overdue_unmatched_passages() TO service_role;
