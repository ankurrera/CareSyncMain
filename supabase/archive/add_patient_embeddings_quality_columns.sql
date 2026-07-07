-- Migration: Add missing metadata and quality columns to patient_embeddings table
-- Resolves PostgREST Schema Cache Drift (PGRST204)

ALTER TABLE patient_embeddings
  ADD COLUMN IF NOT EXISTS brightness float8,
  ADD COLUMN IF NOT EXISTS sharpness float8,
  ADD COLUMN IF NOT EXISTS capture_time timestamptz,
  ADD COLUMN IF NOT EXISTS device_info text,
  ADD COLUMN IF NOT EXISTS camera text,
  ADD COLUMN IF NOT EXISTS enrollment_session_id text,
  ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;

-- Notify PostgREST to reload the schema cache so the new columns are immediately detected
NOTIFY pgrst, 'reload schema';
