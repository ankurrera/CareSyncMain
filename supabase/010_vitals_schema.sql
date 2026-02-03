-- CareSync Vitals Schema
-- Run this in your Supabase SQL Editor

-- ============================================================================
-- VITALS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS vitals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('blood_pressure', 'glucose', 'weight', 'heart_rate')),
    value TEXT NOT NULL, -- Encrypted string (Base64)
    unit TEXT NOT NULL,
    recorded_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================================
ALTER TABLE vitals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Patients can manage their own vitals"
    ON vitals FOR ALL
    USING (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));

CREATE POLICY "Doctors can view patient vitals"
    ON vitals FOR SELECT
    USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'doctor');

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_vitals_patient ON vitals(patient_id);
CREATE INDEX IF NOT EXISTS idx_vitals_type ON vitals(type);
CREATE INDEX IF NOT EXISTS idx_vitals_recorded_at ON vitals(recorded_at);
