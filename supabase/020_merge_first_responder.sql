-- CareSync Migration: Merge First Responder into Patient role
-- This SQL refactors the database to remove the first_responder role
-- and allow patients to request emergency access for lookups.

-- 1. Migrate existing first responder profiles to patient role
UPDATE profiles 
SET role = 'patient' 
WHERE role = 'first_responder';

-- 2. Drop obsolete first_responders table
DROP TABLE IF EXISTS first_responders CASCADE;

-- 3. Update profiles role check constraint
-- Drop old constraint first (name is profiles_role_check)
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
-- Add updated check constraint excluding first_responder
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check CHECK (role IN ('patient', 'doctor', 'pharmacist'));

-- 4. Update emergency_access requester_role check constraint
UPDATE emergency_access SET requester_role = 'patient' WHERE requester_role = 'first_responder';
ALTER TABLE emergency_access DROP CONSTRAINT IF EXISTS emergency_access_requester_role_check;
ALTER TABLE emergency_access ADD CONSTRAINT emergency_access_requester_role_check CHECK (requester_role IN ('doctor', 'patient'));

-- 5. Update emergency_access INSERT policy to allow patients
DROP POLICY IF EXISTS "Doctors and first responders can request emergency access" ON emergency_access;
CREATE POLICY "Doctors and patients can request emergency access"
ON emergency_access
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = requester_id
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role IN ('doctor', 'patient')
  )
);

-- 6. Update storage policies for 'emergency-scans' bucket to allow patients
DROP POLICY IF EXISTS "Medical staff can upload emergency scans" ON storage.objects;
CREATE POLICY "Medical staff can upload emergency scans" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'emergency-scans'
        AND (SELECT role FROM profiles WHERE id = auth.uid()) IN ('patient', 'doctor')
    );

DROP POLICY IF EXISTS "Medical staff can view emergency scans" ON storage.objects;
CREATE POLICY "Medical staff can view emergency scans" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'emergency-scans'
        AND (SELECT role FROM profiles WHERE id = auth.uid()) IN ('patient', 'doctor')
    );

DROP POLICY IF EXISTS "Medical staff can delete emergency scans" ON storage.objects;
CREATE POLICY "Medical staff can delete emergency scans" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'emergency-scans'
        AND (SELECT role FROM profiles WHERE id = auth.uid()) IN ('patient', 'doctor')
    );

-- 7. RLS updates for emergency views
-- Enable anyone authenticated to query profiles of role 'patient' in emergencies
DROP POLICY IF EXISTS "profiles_emergency_view" ON profiles;
CREATE POLICY "profiles_emergency_view"
    ON profiles FOR SELECT
    USING (role = 'patient');

-- Enable patients to be selected by authenticated users in emergencies
DROP POLICY IF EXISTS "patients_emergency_view" ON patients;
CREATE POLICY "patients_emergency_view"
    ON patients FOR SELECT
    USING (auth.uid() IS NOT NULL);

-- Update medical conditions policy to allow patients to view public medical conditions of other patients
DROP POLICY IF EXISTS "medical_conditions_first_responders_view_public" ON medical_conditions;
DROP POLICY IF EXISTS "medical_conditions_patients_view_public" ON medical_conditions;
CREATE POLICY "medical_conditions_patients_view_public"
    ON medical_conditions FOR SELECT
    USING (
        is_public = TRUE 
        AND auth.uid() IS NOT NULL
    );

-- Add public prescriptions view policy
DROP POLICY IF EXISTS "prescriptions_emergency_view_public" ON prescriptions;
CREATE POLICY "prescriptions_emergency_view_public"
    ON prescriptions FOR SELECT
    USING (
        is_public = TRUE
    );

-- Add public prescription items view policy
DROP POLICY IF EXISTS "prescription_items_emergency_view_public" ON prescription_items;
CREATE POLICY "prescription_items_emergency_view_public"
    ON prescription_items FOR SELECT
    USING (
        prescription_id IN (
            SELECT id FROM prescriptions WHERE is_public = TRUE
        )
    );
