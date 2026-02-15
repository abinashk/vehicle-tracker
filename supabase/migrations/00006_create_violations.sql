-- Migration: Create violations table
-- Description: Records of speed or overstay violations detected from matched passages

CREATE TABLE public.violations (
    id                  uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_passage_id    uuid          NOT NULL UNIQUE REFERENCES public.vehicle_passages(id) ON DELETE RESTRICT,
    exit_passage_id     uuid          NOT NULL REFERENCES public.vehicle_passages(id) ON DELETE RESTRICT,
    segment_id          uuid          NOT NULL REFERENCES public.highway_segments(id) ON DELETE RESTRICT,
    violation_type      text          NOT NULL CHECK (violation_type IN ('speeding', 'overstay')),
    plate_number        text          NOT NULL,
    vehicle_type        text          NOT NULL,
    entry_time          timestamptz   NOT NULL,
    exit_time           timestamptz   NOT NULL,
    travel_time_minutes numeric(8,2)  NOT NULL,
    threshold_minutes   numeric(8,2)  NOT NULL,
    calculated_speed_kmh numeric(6,2),
    speed_limit_kmh     numeric(5,2),
    distance_km         numeric(6,2),
    alert_delivered_at  timestamptz,
    created_at          timestamptz   NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.violations IS 'Detected violations from matched vehicle passages';
COMMENT ON COLUMN public.violations.entry_passage_id IS 'The entry passage (UNIQUE ensures one violation per entry)';
COMMENT ON COLUMN public.violations.travel_time_minutes IS 'Actual travel time between entry and exit checkposts';
COMMENT ON COLUMN public.violations.threshold_minutes IS 'The threshold that was violated (min_travel_time for speeding, max_travel_time for overstay)';
COMMENT ON COLUMN public.violations.calculated_speed_kmh IS 'Calculated average speed: distance_km / (travel_time_minutes / 60)';
COMMENT ON COLUMN public.violations.speed_limit_kmh IS 'Snapshot of max_speed_kmh at time of violation';
COMMENT ON COLUMN public.violations.distance_km IS 'Snapshot of segment distance at time of violation';
