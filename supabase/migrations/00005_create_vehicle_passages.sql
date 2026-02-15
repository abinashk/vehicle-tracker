-- Migration: Create vehicle_passages table
-- Description: Core high-volume table recording every vehicle passing through a checkpost

CREATE TABLE public.vehicle_passages (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id           uuid        NOT NULL UNIQUE,
    plate_number        text        NOT NULL,
    plate_number_raw    text,
    vehicle_type        text        NOT NULL CHECK (vehicle_type IN (
                                        'car', 'jeep', 'pickup', 'van',
                                        'minibus', 'bus', 'truck', 'tanker',
                                        'motorcycle', 'other'
                                    )),
    checkpost_id        uuid        NOT NULL REFERENCES public.checkposts(id) ON DELETE RESTRICT,
    segment_id          uuid        NOT NULL REFERENCES public.highway_segments(id) ON DELETE RESTRICT,
    recorded_at         timestamptz NOT NULL,
    server_received_at  timestamptz NOT NULL DEFAULT now(),
    ranger_id           uuid        NOT NULL REFERENCES public.user_profiles(id) ON DELETE RESTRICT,
    photo_path          text,
    source              text        NOT NULL DEFAULT 'app' CHECK (source IN ('app', 'sms')),
    matched_passage_id  uuid        REFERENCES public.vehicle_passages(id) ON DELETE SET NULL,
    is_entry            boolean,
    created_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.vehicle_passages IS 'Records of vehicles passing through checkposts. Core table for speed monitoring.';
COMMENT ON COLUMN public.vehicle_passages.client_id IS 'Client-generated idempotency key. Prevents duplicate inserts on retry.';
COMMENT ON COLUMN public.vehicle_passages.plate_number IS 'Normalized plate number (English transliteration)';
COMMENT ON COLUMN public.vehicle_passages.plate_number_raw IS 'Original OCR output before normalization';
COMMENT ON COLUMN public.vehicle_passages.recorded_at IS 'Device timestamp at the moment of capture (camera shutter time)';
COMMENT ON COLUMN public.vehicle_passages.server_received_at IS 'Server timestamp when the record was received';
COMMENT ON COLUMN public.vehicle_passages.matched_passage_id IS 'Self-referencing FK to the paired entry/exit passage';
COMMENT ON COLUMN public.vehicle_passages.is_entry IS 'TRUE if this is the entry passage, FALSE if exit. NULL if unmatched.';
