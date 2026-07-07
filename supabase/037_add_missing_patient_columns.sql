-- Migration 037: Add missing height and weight columns to patients table
ALTER TABLE patients 
  ADD COLUMN IF NOT EXISTS height double precision,
  ADD COLUMN IF NOT EXISTS weight double precision;

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
