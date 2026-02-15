-- Migration: Create parks table
-- Description: Core table for national parks in the system

CREATE TABLE public.parks (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    name        text        NOT NULL UNIQUE,
    code        text        NOT NULL UNIQUE CHECK (char_length(code) <= 10),
    is_active   boolean     NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.parks IS 'National parks monitored by the vehicle tracking system';
COMMENT ON COLUMN public.parks.code IS 'Short unique code (max 10 chars), e.g. BNP for Banke National Park';
