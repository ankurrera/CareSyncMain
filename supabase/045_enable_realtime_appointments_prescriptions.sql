-- Migration 045: Optimize Booking & Enable Realtime for CareSync Workflows

-- ============================================================================
-- 1. CONCURRENCY & DOUBLE BOOKING CONSTRAINTS
-- ============================================================================

-- Prevent booking overlapping scheduled appointments for the same doctor
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_doctor_appointment
ON public.appointments (doctor_id, start_time)
WHERE (status = 'scheduled');

-- Prevent a patient from booking multiple overlapping scheduled appointments at the same time
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_patient_appointment
ON public.appointments (patient_id, start_time)
WHERE (status = 'scheduled');

-- ============================================================================
-- 2. ENABLE SUPABASE REALTIME
-- ============================================================================

-- Idempotently add tables to the 'supabase_realtime' publication
DO $$
BEGIN
  -- Add public.appointments
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'appointments'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.appointments;
  END IF;

  -- Add public.prescriptions
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'prescriptions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.prescriptions;
  END IF;

  -- Add public.prescription_items
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'prescription_items'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.prescription_items;
  END IF;

  -- Add public.dispensing_records
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'dispensing_records'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.dispensing_records;
  END IF;
END $$;
