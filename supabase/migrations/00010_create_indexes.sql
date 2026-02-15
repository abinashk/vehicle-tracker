-- Migration: Create performance indexes
-- Description: Indexes for query optimization across all tables

-- Parks
CREATE INDEX idx_parks_code ON public.parks (code);

-- Highway Segments
CREATE INDEX idx_highway_segments_park_id ON public.highway_segments (park_id);

-- Checkposts
CREATE INDEX idx_checkposts_segment_id ON public.checkposts (segment_id);
CREATE INDEX idx_checkposts_code ON public.checkposts (code);

-- User Profiles
CREATE INDEX idx_user_profiles_role ON public.user_profiles (role);
CREATE INDEX idx_user_profiles_assigned_checkpost_id ON public.user_profiles (assigned_checkpost_id);

-- Vehicle Passages (high-volume table, indexes are critical)
-- Primary matching lookup: find passages by plate + segment, most recent first
CREATE INDEX idx_vehicle_passages_plate_segment_recorded
    ON public.vehicle_passages (plate_number, segment_id, recorded_at DESC);

-- Checkpost listing: passages at a specific checkpost, most recent first
CREATE INDEX idx_vehicle_passages_checkpost_recorded
    ON public.vehicle_passages (checkpost_id, recorded_at DESC);

-- Partial index for unmatched entries: only index rows that haven't been matched yet
CREATE INDEX idx_vehicle_passages_unmatched
    ON public.vehicle_passages (segment_id, recorded_at)
    WHERE matched_passage_id IS NULL;

-- client_id already has a UNIQUE constraint which creates an implicit index

-- Violations
CREATE INDEX idx_violations_segment_created
    ON public.violations (segment_id, created_at DESC);

CREATE INDEX idx_violations_plate_number
    ON public.violations (plate_number);

CREATE INDEX idx_violations_violation_type
    ON public.violations (violation_type);

-- Proactive Overstay Alerts
-- Partial index for unresolved alerts (the most frequently queried subset)
CREATE INDEX idx_proactive_overstay_alerts_unresolved
    ON public.proactive_overstay_alerts (segment_id, entry_time)
    WHERE resolved = false;
