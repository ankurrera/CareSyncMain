-- Migration: Fix biometric_access_logs target_patient_id foreign key mapping
-- Drops the incorrect foreign key referencing profiles.id, maps existing logs to patients.id, and points the FK to patients.id

-- 1. Drop the incorrect constraint referencing profiles.id
ALTER TABLE biometric_access_logs
  DROP CONSTRAINT IF EXISTS biometric_access_logs_target_patient_id_fkey;

-- 2. Temporarily disable the immutability trigger to allow updates for migration
ALTER TABLE biometric_access_logs DISABLE TRIGGER trigger_prevent_audit_changes;

-- 3. Update existing log rows to map profiles.id (user_id) to their corresponding patients.id
UPDATE biometric_access_logs log
SET target_patient_id = p.id
FROM patients p
WHERE log.target_patient_id = p.user_id;

-- 4. Clean up any remaining invalid target_patient_ids by setting them to NULL (as permitted by the schema)
UPDATE biometric_access_logs
SET target_patient_id = NULL
WHERE target_patient_id NOT IN (SELECT id FROM patients);

-- 5. Re-enable the immutability trigger
ALTER TABLE biometric_access_logs ENABLE TRIGGER trigger_prevent_audit_changes;

-- 6. Re-add the constraint pointing to patients.id
ALTER TABLE biometric_access_logs
  ADD CONSTRAINT biometric_access_logs_target_patient_id_fkey
  FOREIGN KEY (target_patient_id) REFERENCES patients(id) ON DELETE SET NULL;
