-- CareSync Sprint 1 Performance Index Optimization
-- Speeds up paginated queries and filters for audit logs, prescriptions, and appointments.

-- 1. Index for paginated audit log queries (filtering by user_id and sorting by timestamp)
CREATE INDEX IF NOT EXISTS idx_audit_log_user_timestamp
ON public.audit_log(user_id, timestamp DESC);

-- 2. Index for patient prescription queries (filtering by patient_id and sorting by created_at)
CREATE INDEX IF NOT EXISTS idx_prescriptions_patient_id
ON public.prescriptions(patient_id, created_at DESC);

-- 3. Index for appointments lookup (filtering by patient_id/doctor_id and sorting by start_time)
CREATE INDEX IF NOT EXISTS idx_appointments_patient_time
ON public.appointments(patient_id, start_time DESC);

CREATE INDEX IF NOT EXISTS idx_appointments_doctor_time
ON public.appointments(doctor_id, start_time DESC);
