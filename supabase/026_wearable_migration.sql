-- CareSync Wearable Integration Schema Migration
-- Run this in your Supabase SQL Editor

-- Add Wearable metadata columns to vitals table
ALTER TABLE vitals ADD COLUMN IF NOT EXISTS source VARCHAR(50) DEFAULT 'manual';
ALTER TABLE vitals ADD COLUMN IF NOT EXISTS platform VARCHAR(50);
ALTER TABLE vitals ADD COLUMN IF NOT EXISTS device_name VARCHAR(100);
ALTER TABLE vitals ADD COLUMN IF NOT EXISTS device_id VARCHAR(100);
ALTER TABLE vitals ADD COLUMN IF NOT EXISTS synced_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE vitals ADD COLUMN IF NOT EXISTS confidence DOUBLE PRECISION;
ALTER TABLE vitals ADD COLUMN IF NOT EXISTS duplicate_hash VARCHAR(64);

-- Add unique constraint to prevent duplicate imports for identical timestamp, metric type, and duplicate hash
-- If duplicate_hash is null (e.g. manual logs), we do not enforce unique_vital_reading
ALTER TABLE vitals ADD CONSTRAINT unique_vital_reading UNIQUE (patient_id, type, recorded_at, duplicate_hash);

-- Create index for quick lookup of duplicate checks
CREATE INDEX IF NOT EXISTS idx_vitals_duplicate_hash ON vitals(duplicate_hash);
