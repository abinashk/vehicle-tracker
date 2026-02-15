-- Migration: Create highway_segments table
-- Description: Highway segments passing through national parks, with speed thresholds

CREATE TABLE public.highway_segments (
    id                      uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
    park_id                 uuid          NOT NULL REFERENCES public.parks(id) ON DELETE CASCADE,
    name                    text          NOT NULL,
    distance_km             numeric(6,2)  NOT NULL CHECK (distance_km > 0),
    max_speed_kmh           numeric(5,2)  NOT NULL CHECK (max_speed_kmh > 0),
    min_speed_kmh           numeric(5,2)  NOT NULL CHECK (min_speed_kmh > 0),
    min_travel_time_minutes numeric(8,2)  GENERATED ALWAYS AS ((distance_km / max_speed_kmh) * 60) STORED,
    max_travel_time_minutes numeric(8,2)  GENERATED ALWAYS AS ((distance_km / min_speed_kmh) * 60) STORED,
    is_active               boolean       NOT NULL DEFAULT true,
    created_at              timestamptz   NOT NULL DEFAULT now(),
    updated_at              timestamptz   NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.highway_segments IS 'Highway segments through parks with distance and speed limit configuration';
COMMENT ON COLUMN public.highway_segments.min_travel_time_minutes IS 'Fastest allowed travel time (based on max_speed_kmh). Travel faster than this = speeding.';
COMMENT ON COLUMN public.highway_segments.max_travel_time_minutes IS 'Slowest expected travel time (based on min_speed_kmh). Travel slower than this = potential overstay.';
