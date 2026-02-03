-- ============================================================================
-- FIX DOCTOR VISIBILITY IN CARE-SYNC
-- ============================================================================
-- Run this in your Supabase SQL Editor if patients cannot see doctors.

-- 1. PROFILES TABLE: Allow everyone to see doctors
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Public profiles are viewable by everyone"
    ON public.profiles FOR SELECT
    USING (TRUE);

-- 2. DOCTORS TABLE: Allow everyone to see details
DROP POLICY IF EXISTS "Anyone can view doctor details" ON public.doctors;
CREATE POLICY "Anyone can view doctor details"
    ON public.doctors FOR SELECT
    USING (TRUE);

-- 3. Ensure Doctor Availability is visible (already in schema but good to verify)
DROP POLICY IF EXISTS "Anyone can view doctor availability" ON public.doctor_availability;
CREATE POLICY "Anyone can view doctor availability"
    ON public.doctor_availability FOR SELECT
    USING (TRUE);
