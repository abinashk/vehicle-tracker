-- Migration: Create Row Level Security policies
-- Description: RLS policies for all tables based on user roles (ranger, admin)

-- =============================================================================
-- Helper function to get current user's role
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT role FROM public.user_profiles WHERE id = auth.uid();
$$;

-- Helper function to get current user's assigned segment_id (via checkpost)
CREATE OR REPLACE FUNCTION public.get_user_segment_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT c.segment_id
    FROM public.user_profiles up
    JOIN public.checkposts c ON c.id = up.assigned_checkpost_id
    WHERE up.id = auth.uid();
$$;

-- Helper function to get current user's assigned checkpost_id
CREATE OR REPLACE FUNCTION public.get_user_checkpost_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT assigned_checkpost_id FROM public.user_profiles WHERE id = auth.uid();
$$;

-- =============================================================================
-- PARKS
-- =============================================================================
ALTER TABLE public.parks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "parks_select_authenticated"
    ON public.parks FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "parks_all_admin"
    ON public.parks FOR ALL
    TO authenticated
    USING (public.get_user_role() = 'admin')
    WITH CHECK (public.get_user_role() = 'admin');

-- =============================================================================
-- HIGHWAY SEGMENTS
-- =============================================================================
ALTER TABLE public.highway_segments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "highway_segments_select_authenticated"
    ON public.highway_segments FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "highway_segments_all_admin"
    ON public.highway_segments FOR ALL
    TO authenticated
    USING (public.get_user_role() = 'admin')
    WITH CHECK (public.get_user_role() = 'admin');

-- =============================================================================
-- CHECKPOSTS
-- =============================================================================
ALTER TABLE public.checkposts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "checkposts_select_authenticated"
    ON public.checkposts FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "checkposts_all_admin"
    ON public.checkposts FOR ALL
    TO authenticated
    USING (public.get_user_role() = 'admin')
    WITH CHECK (public.get_user_role() = 'admin');

-- =============================================================================
-- USER PROFILES
-- =============================================================================
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Rangers can see their own profile
CREATE POLICY "user_profiles_select_own"
    ON public.user_profiles FOR SELECT
    TO authenticated
    USING (
        id = auth.uid()
        OR public.get_user_role() = 'admin'
    );

-- Admins can do everything
CREATE POLICY "user_profiles_all_admin"
    ON public.user_profiles FOR ALL
    TO authenticated
    USING (public.get_user_role() = 'admin')
    WITH CHECK (public.get_user_role() = 'admin');

-- =============================================================================
-- VEHICLE PASSAGES
-- =============================================================================
ALTER TABLE public.vehicle_passages ENABLE ROW LEVEL SECURITY;

-- Rangers can see passages from their own segment
CREATE POLICY "vehicle_passages_select_own_segment"
    ON public.vehicle_passages FOR SELECT
    TO authenticated
    USING (
        segment_id = public.get_user_segment_id()
        OR public.get_user_role() = 'admin'
    );

-- Rangers can insert passages for their own checkpost
CREATE POLICY "vehicle_passages_insert_own_checkpost"
    ON public.vehicle_passages FOR INSERT
    TO authenticated
    WITH CHECK (
        checkpost_id = public.get_user_checkpost_id()
        OR public.get_user_role() = 'admin'
    );

-- Rangers can update photo_path on their own records
CREATE POLICY "vehicle_passages_update_own"
    ON public.vehicle_passages FOR UPDATE
    TO authenticated
    USING (
        ranger_id = auth.uid()
        OR public.get_user_role() = 'admin'
    )
    WITH CHECK (
        ranger_id = auth.uid()
        OR public.get_user_role() = 'admin'
    );

-- Admins can delete
CREATE POLICY "vehicle_passages_delete_admin"
    ON public.vehicle_passages FOR DELETE
    TO authenticated
    USING (public.get_user_role() = 'admin');

-- =============================================================================
-- VIOLATIONS
-- =============================================================================
ALTER TABLE public.violations ENABLE ROW LEVEL SECURITY;

-- Rangers can see violations from their own segment
CREATE POLICY "violations_select_own_segment"
    ON public.violations FOR SELECT
    TO authenticated
    USING (
        segment_id = public.get_user_segment_id()
        OR public.get_user_role() = 'admin'
    );

-- Admins can do everything
CREATE POLICY "violations_all_admin"
    ON public.violations FOR ALL
    TO authenticated
    USING (public.get_user_role() = 'admin')
    WITH CHECK (public.get_user_role() = 'admin');

-- =============================================================================
-- VIOLATION OUTCOMES
-- =============================================================================
ALTER TABLE public.violation_outcomes ENABLE ROW LEVEL SECURITY;

-- Rangers can see outcomes from their own segment
CREATE POLICY "violation_outcomes_select_own_segment"
    ON public.violation_outcomes FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.violations v
            WHERE v.id = violation_id
            AND v.segment_id = public.get_user_segment_id()
        )
        OR public.get_user_role() = 'admin'
    );

-- Rangers can insert outcomes
CREATE POLICY "violation_outcomes_insert_ranger"
    ON public.violation_outcomes FOR INSERT
    TO authenticated
    WITH CHECK (
        recorded_by = auth.uid()
        OR public.get_user_role() = 'admin'
    );

-- Rangers can update their own outcomes within 24 hours
CREATE POLICY "violation_outcomes_update_own_24h"
    ON public.violation_outcomes FOR UPDATE
    TO authenticated
    USING (
        (recorded_by = auth.uid() AND recorded_at > now() - interval '24 hours')
        OR public.get_user_role() = 'admin'
    )
    WITH CHECK (
        (recorded_by = auth.uid() AND recorded_at > now() - interval '24 hours')
        OR public.get_user_role() = 'admin'
    );

-- Admins can delete
CREATE POLICY "violation_outcomes_delete_admin"
    ON public.violation_outcomes FOR DELETE
    TO authenticated
    USING (public.get_user_role() = 'admin');

-- =============================================================================
-- PROACTIVE OVERSTAY ALERTS
-- =============================================================================
ALTER TABLE public.proactive_overstay_alerts ENABLE ROW LEVEL SECURITY;

-- Rangers can see alerts from their own segment
CREATE POLICY "proactive_overstay_alerts_select_own_segment"
    ON public.proactive_overstay_alerts FOR SELECT
    TO authenticated
    USING (
        segment_id = public.get_user_segment_id()
        OR public.get_user_role() = 'admin'
    );

-- Admins can do everything
CREATE POLICY "proactive_overstay_alerts_all_admin"
    ON public.proactive_overstay_alerts FOR ALL
    TO authenticated
    USING (public.get_user_role() = 'admin')
    WITH CHECK (public.get_user_role() = 'admin');

-- =============================================================================
-- SYNC METADATA
-- =============================================================================
ALTER TABLE public.sync_metadata ENABLE ROW LEVEL SECURITY;

-- Users can see and manage their own sync metadata
CREATE POLICY "sync_metadata_select_own"
    ON public.sync_metadata FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        OR public.get_user_role() = 'admin'
    );

CREATE POLICY "sync_metadata_insert_own"
    ON public.sync_metadata FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "sync_metadata_update_own"
    ON public.sync_metadata FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "sync_metadata_all_admin"
    ON public.sync_metadata FOR ALL
    TO authenticated
    USING (public.get_user_role() = 'admin')
    WITH CHECK (public.get_user_role() = 'admin');
