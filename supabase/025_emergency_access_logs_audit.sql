-- Create table for Emergency Access Logs (Immutable Audit Trail)
CREATE TABLE IF NOT EXISTS emergency_access_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    accessed_by_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    accessed_by_name TEXT NOT NULL DEFAULT 'Unknown Provider',
    accessed_by_role TEXT NOT NULL DEFAULT 'unknown',
    hospital_name TEXT,
    organization_name TEXT,
    device_id TEXT,
    device_name TEXT,
    device_platform TEXT,
    authentication_method TEXT NOT NULL CHECK (authentication_method IN ('Face Recognition', 'QR Code', 'Manual Emergency Override')),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    city TEXT,
    state TEXT,
    country TEXT,
    ip_address TEXT,
    confidence_score DOUBLE PRECISION,
    access_status TEXT NOT NULL CHECK (access_status IN ('Success', 'Failed', 'Denied', 'Expired')),
    reason_for_access TEXT CHECK (reason_for_access IN ('Emergency Treatment', 'Trauma', 'Cardiac Arrest', 'Stroke', 'Unknown Patient')),
    view_scope TEXT NOT NULL CHECK (view_scope IN ('Emergency ID Only', 'Emergency Summary', 'Full Emergency Record')),
    session_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure columns exist if the table was created under a legacy schema version
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS patient_id UUID REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS accessed_by_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS accessed_by_name TEXT;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS accessed_by_role TEXT;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS hospital_name TEXT;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS organization_name TEXT;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS device_id TEXT;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS device_name TEXT;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS device_platform TEXT;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS authentication_method TEXT;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS state TEXT;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS country TEXT;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS ip_address TEXT;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS confidence_score DOUBLE PRECISION;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS access_status TEXT;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS reason_for_access TEXT;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS view_scope TEXT;
ALTER TABLE emergency_access_logs ADD COLUMN IF NOT EXISTS session_id TEXT;

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEXES FOR HIGH-PERFORMANCE TIMELINE
-- ═══════════════════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_emergency_access_logs_patient_id ON emergency_access_logs(patient_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_emergency_access_logs_timestamp ON emergency_access_logs(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_emergency_access_logs_status_method ON emergency_access_logs(patient_id, access_status, authentication_method);

-- ═══════════════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY (RLS)
-- ═══════════════════════════════════════════════════════════════════════════
ALTER TABLE emergency_access_logs ENABLE ROW LEVEL SECURITY;

-- Patients can only view their own logs
CREATE POLICY "Patients can view their own emergency access logs"
ON emergency_access_logs
FOR SELECT
TO authenticated
USING (auth.uid() = patient_id);

-- Admins can view all logs for investigation
CREATE POLICY "Admins can view all emergency access logs"
ON emergency_access_logs
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role = 'admin'
  )
);

-- Requesters can insert logs
CREATE POLICY "Authenticated users can insert emergency access logs"
ON emergency_access_logs
FOR INSERT
TO authenticated
WITH CHECK (true);

-- ═══════════════════════════════════════════════════════════════════════════
-- IMMUTABILITY ENFORCEMENT
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION prevent_modify_emergency_access_logs()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'emergency_access_logs table is immutable. Updates or deletions are strictly prohibited.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_prevent_update_delete_audit_logs
BEFORE UPDATE OR DELETE ON emergency_access_logs
FOR EACH ROW
EXECUTE FUNCTION prevent_modify_emergency_access_logs();

-- ═══════════════════════════════════════════════════════════════════════════
-- TRIGGER: AUTO-MIRROR MANUAL OVERRIDES
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION log_manual_override_emergency_access()
RETURNS TRIGGER AS $$
DECLARE
    requester_name TEXT;
    hosp_name TEXT;
BEGIN
    SELECT full_name, hospital_clinic_name INTO requester_name, hosp_name
    FROM profiles
    WHERE id = NEW.requester_id;

    INSERT INTO emergency_access_logs (
        patient_id,
        accessed_by_user_id,
        accessed_by_name,
        accessed_by_role,
        hospital_name,
        authentication_method,
        access_status,
        reason_for_access,
        view_scope,
        session_id,
        timestamp
    ) VALUES (
        NEW.patient_id,
        NEW.requester_id,
        COALESCE(requester_name, 'Unknown Provider'),
        NEW.requester_role,
        hosp_name,
        'Manual Emergency Override',
        'Success',
        CASE 
            WHEN NEW.reason ILIKE '%trauma%' THEN 'Trauma'
            WHEN NEW.reason ILIKE '%cardiac%' THEN 'Cardiac Arrest'
            WHEN NEW.reason ILIKE '%stroke%' THEN 'Stroke'
            ELSE 'Emergency Treatment'
        END,
        'Full Emergency Record',
        NEW.id::TEXT,
        NEW.granted_at
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_log_manual_override_emergency_access
AFTER INSERT ON emergency_access
FOR EACH ROW
EXECUTE FUNCTION log_manual_override_emergency_access();
