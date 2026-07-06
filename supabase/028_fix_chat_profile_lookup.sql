-- ============================================================================
-- Fix: Chat profile lookup by email (case-insensitive)
-- ============================================================================
-- Problem 1: RLS on profiles table blocks patients from looking up doctor
--            profiles (and vice-versa) by email when starting a chat.
-- Problem 2: Direct email match is case-sensitive; stored emails may differ
--            in casing from what the user types.
--
-- Solution: A SECURITY DEFINER function that any authenticated user can call
--           to find another user's profile by email (case-insensitive).
--           Only exposes the minimum fields needed for chat initiation.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.find_profile_by_email(target_email TEXT)
RETURNS TABLE (
    id          UUID,
    full_name   TEXT,
    role        TEXT,
    avatar_url  TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Only allow authenticated users to call this function
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT
        p.id,
        p.full_name,
        p.role,
        p.avatar_url
    FROM profiles p
    WHERE LOWER(p.email) = LOWER(TRIM(target_email))
    LIMIT 1;
END;
$$;

-- Grant execute to authenticated users only
REVOKE ALL ON FUNCTION public.find_profile_by_email(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.find_profile_by_email(TEXT) TO authenticated;
