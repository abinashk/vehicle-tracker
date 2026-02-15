-- Migration: Create proactive_overstay_alerts table
-- Description: Alerts for vehicles that entered but haven't exited within expected time

CREATE TABLE public.proactive_overstay_alerts (
    id                      uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_passage_id        uuid        NOT NULL REFERENCES public.vehicle_passages(id) ON DELETE CASCADE,
    segment_id              uuid        NOT NULL REFERENCES public.highway_segments(id) ON DELETE RESTRICT,
    plate_number            text        NOT NULL,
    vehicle_type            text        NOT NULL,
    entry_time              timestamptz NOT NULL,
    expected_exit_by        timestamptz NOT NULL,
    resolved                boolean     NOT NULL DEFAULT false,
    resolved_at             timestamptz,
    resolved_by_passage_id  uuid        REFERENCES public.vehicle_passages(id) ON DELETE SET NULL,
    created_at              timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.proactive_overstay_alerts IS 'Proactive alerts for vehicles that have not exited within expected max travel time';
COMMENT ON COLUMN public.proactive_overstay_alerts.expected_exit_by IS 'entry_time + max_travel_time_minutes from the segment';
COMMENT ON COLUMN public.proactive_overstay_alerts.resolved IS 'TRUE when the vehicle eventually exits or the alert is manually resolved';
COMMENT ON COLUMN public.proactive_overstay_alerts.resolved_by_passage_id IS 'The exit passage that resolved this alert, if any';
