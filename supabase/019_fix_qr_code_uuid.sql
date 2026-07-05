-- CareSync Migration: Fix non-UUID qr_code_id values
-- Run this in the Supabase SQL Editor to migrate any existing patients
-- whose qr_code_id was set to a timestamp string (13-digit number)
-- rather than a proper UUID v4.
--
-- Safe to run multiple times (idempotent).

UPDATE patients
SET qr_code_id = gen_random_uuid()::text
WHERE qr_code_id ~ '^\d+$';   -- matches pure numeric strings (old timestamp format)

-- Verify: how many rows were fixed
SELECT
  COUNT(*) FILTER (WHERE qr_code_id ~ '^\d+$')   AS still_invalid,
  COUNT(*) FILTER (WHERE qr_code_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') AS valid_uuid
FROM patients;
