-- ============================================================================
-- SEED TEST DOCTORS FOR CARE-SYNC
-- ============================================================================
-- IMPORTANT: Run this in your Supabase SQL Editor.
-- This script adds test doctors with complete profiles, professional metadata, 
-- and default weekly availability for appointment booking.

-- 1. Insert into auth.users (auth schema handled by Supabase)
-- These users are created for the list, though you won't have their passwords.
-- If you need to log in, replace their IDs with users you've signed up as.

DO $$
DECLARE
    dr_smith_id UUID := uuid_generate_v4();
    dr_johnson_id UUID := uuid_generate_v4();
    dr_williams_id UUID := uuid_generate_v4();
BEGIN
    -- Dr. Sarah Smith (General Practitioner)
    INSERT INTO auth.users (id, email, raw_user_meta_data, role, aud, email_confirmed_at, last_sign_in_at, created_at, updated_at)
    VALUES (
        dr_smith_id,
        'dr.smith@caresync.test',
        '{"full_name": "Dr. Sarah Smith", "role": "doctor"}',
        'authenticated', 'authenticated', NOW(), NOW(), NOW(), NOW()
    );

    -- Dr. Michael Johnson (Cardiologist)
    INSERT INTO auth.users (id, email, raw_user_meta_data, role, aud, email_confirmed_at, last_sign_in_at, created_at, updated_at)
    VALUES (
        dr_johnson_id,
        'dr.johnson@caresync.test',
        '{"full_name": "Dr. Michael Johnson", "role": "doctor"}',
        'authenticated', 'authenticated', NOW(), NOW(), NOW(), NOW()
    );

    -- Dr. Emily Williams (Pediatrician)
    INSERT INTO auth.users (id, email, raw_user_meta_data, role, aud, email_confirmed_at, last_sign_in_at, created_at, updated_at)
    VALUES (
        dr_williams_id,
        'dr.williams@caresync.test',
        '{"full_name": "Dr. Emily Williams", "role": "doctor"}',
        'authenticated', 'authenticated', NOW(), NOW(), NOW(), NOW()
    );

    -- Note: The trigger 'on_auth_user_created' will automatically create the corresponding entries
    -- in public.profiles. We now proceed to insert their professional metadata.

    -- 2. Insert into public.doctors table
    INSERT INTO public.doctors (user_id, license_number, specialization, hospital_affiliation)
    VALUES 
        (dr_smith_id, 'LIC-100201', 'General Practitioner', 'Downtown General Hospital'),
        (dr_johnson_id, 'LIC-200304', 'Cardiologist', 'Hearts & Health Specialty Clinic'),
        (dr_williams_id, 'LIC-300405', 'Pediatrician', 'Caresync Children''s Center');

    -- 3. Insert default weekly availability (Monday to Friday, 09:00 to 17:00)
    -- This ensures they show up as bookable for patients.
    INSERT INTO public.doctor_availability (doctor_id, day_of_week, start_time, end_time, is_active)
    SELECT u.id, d, '09:00:00'::TIME, '17:00:00'::TIME, TRUE
    FROM (SELECT dr_smith_id as id UNION SELECT dr_johnson_id UNION SELECT dr_williams_id) u
    CROSS JOIN generate_series(1, 5) d; -- 1 (Mon) to 5 (Fri)

END $$;

-- Verify results
-- SELECT email, full_name, role FROM public.profiles WHERE role = 'doctor';
