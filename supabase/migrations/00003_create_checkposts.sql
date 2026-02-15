-- Migration: Create checkposts table
-- Description: Entry/exit checkposts at each end of a highway segment

CREATE TABLE public.checkposts (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    segment_id      uuid        NOT NULL REFERENCES public.highway_segments(id) ON DELETE CASCADE,
    name            text        NOT NULL,
    code            text        NOT NULL UNIQUE,
    position_index  smallint    NOT NULL CHECK (position_index IN (0, 1)),
    latitude        numeric,
    longitude       numeric,
    is_active       boolean     NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT uq_checkposts_segment_position UNIQUE (segment_id, position_index)
);

COMMENT ON TABLE public.checkposts IS 'Checkposts at each end of a highway segment. Each segment has exactly two checkposts (position_index 0 and 1).';
COMMENT ON COLUMN public.checkposts.code IS 'Unique short code used in SMS messages, e.g. BNP-A';
COMMENT ON COLUMN public.checkposts.position_index IS '0 or 1, representing the two ends of the highway segment';
