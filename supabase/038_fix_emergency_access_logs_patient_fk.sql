-- Migration 038: Fix emergency_access_logs patient_id foreign key mapping
-- Drops the incorrect foreign key referencing profiles.id, maps existing logs to patients.id, and points the FK to patients.id

-- 1. Drop the incorrect constraint referencing profiles.id
ALTER TABLE emergency_access_logs
  DROP CONSTRAINT IF EXISTS emergency_access_logs_patient_id_fkey;

-- 2. Temporarily disable the immutability trigger to allow updates for migration
ALTER TABLE emergency_access_logs DISABLE TRIGGER trigger_prevent_update_delete_audit_logs;

-- 3. Update existing log rows to map profiles.id (user_id) to their corresponding patients.id
UPDATE emergency_access_logs log
SET patient_id = p.id
FROM patients p
WHERE log.patient_id = p.user_id;

-- 4. Clean up any remaining invalid patient_ids by setting them to NULL
UPDATE emergency_access_logs
SET patient_id = NULL
WHERE patient_id NOT IN (SELECT id FROM patients);

-- 5. Re-enable the immutability trigger
ALTER TABLE emergency_access_logs ENABLE TRIGGER trigger_prevent_update_delete_audit_logs;

-- 6. Re-add the constraint pointing to patients.id
ALTER TABLE emergency_access_logs
  ADD CONSTRAINT emergency_access_logs_patient_id_fkey
  FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE SET NULL;

-- 7. Update select policy so patients check against patients.id instead of profiles.id
DROP POLICY IF EXISTS "Patients can view their own emergency access logs" ON emergency_access_logs;
CREATE POLICY "Patients can view their own emergency access logs"
ON emergency_access_logs
FOR SELECT
TO authenticated
USING (
  patient_id IN (
    SELECT id FROM patients WHERE user_id = auth.uid()
  )
);
