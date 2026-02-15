-- Migration: Create sync_metadata table
-- Description: Tracks sync state per user per device for offline-first architecture

CREATE TABLE public.sync_metadata (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       uuid        NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    device_id     text        NOT NULL,
    last_sync_at  timestamptz,
    last_pull_at  timestamptz,
    pending_count integer     NOT NULL DEFAULT 0,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT uq_sync_metadata_user_device UNIQUE (user_id, device_id)
);

COMMENT ON TABLE public.sync_metadata IS 'Tracks synchronization state for each user-device pair';
COMMENT ON COLUMN public.sync_metadata.device_id IS 'Unique device identifier';
COMMENT ON COLUMN public.sync_metadata.last_sync_at IS 'Last time the device successfully pushed data to the server';
COMMENT ON COLUMN public.sync_metadata.last_pull_at IS 'Last time the device pulled data from the server';
COMMENT ON COLUMN public.sync_metadata.pending_count IS 'Number of records pending sync on the device';
