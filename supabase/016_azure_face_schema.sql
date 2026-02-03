-- CareSync Azure Face API Database Schema
-- Run this in your Supabase SQL Editor

-- ============================================================================
-- 1. ADD AZURE FACE REFERENCE COLUMNS TO PATIENTS
-- ============================================================================
ALTER TABLE patients ADD COLUMN IF NOT EXISTS azure_person_id TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS azure_persisted_face_id TEXT;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_patients_azure_person_id ON patients(azure_person_id);

-- ============================================================================
-- 2. CREATE EMERGENCY SCANS STORAGE BUCKET
-- ============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('emergency-scans', 'emergency-scans', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 3. STORAGE POLICIES FOR EMERGENCY-SCANS
-- ============================================================================

-- Allow doctors and first responders to upload emergency scans
DROP POLICY IF EXISTS "Medical staff can upload emergency scans" ON storage.objects;
CREATE POLICY "Medical staff can upload emergency scans" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'emergency-scans'
        AND (SELECT role FROM profiles WHERE id = auth.uid()) IN ('first_responder', 'doctor')
    );

-- Allow doctors and first responders to view emergency scans
DROP POLICY IF EXISTS "Medical staff can view emergency scans" ON storage.objects;
CREATE POLICY "Medical staff can view emergency scans" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'emergency-scans'
        AND (SELECT role FROM profiles WHERE id = auth.uid()) IN ('first_responder', 'doctor')
    );

-- Allow doctors and first responders to delete emergency scans (cleanup)
DROP POLICY IF EXISTS "Medical staff can delete emergency scans" ON storage.objects;
CREATE POLICY "Medical staff can delete emergency scans" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'emergency-scans'
        AND (SELECT role FROM profiles WHERE id = auth.uid()) IN ('first_responder', 'doctor')
    );
