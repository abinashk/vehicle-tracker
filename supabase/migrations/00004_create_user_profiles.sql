-- Migration: Create user_profiles table
-- Description: Extends auth.users with application-specific profile data

CREATE TABLE public.user_profiles (
    id                    uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name             text        NOT NULL,
    role                  text        NOT NULL CHECK (role IN ('ranger', 'admin')),
    phone_number          text,
    assigned_checkpost_id uuid        REFERENCES public.checkposts(id) ON DELETE SET NULL,
    assigned_park_id      uuid        REFERENCES public.parks(id) ON DELETE SET NULL,
    is_active             boolean     NOT NULL DEFAULT true,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.user_profiles IS 'Application-level user profiles linked to Supabase auth.users';
COMMENT ON COLUMN public.user_profiles.role IS 'User role: ranger (field operator) or admin (dashboard user)';
COMMENT ON COLUMN public.user_profiles.assigned_checkpost_id IS 'The checkpost this ranger is assigned to. NULL for admins.';
COMMENT ON COLUMN public.user_profiles.assigned_park_id IS 'The park this user belongs to. Used for data scoping.';
