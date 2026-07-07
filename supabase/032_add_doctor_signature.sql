-- Migration: Add digital signature columns to doctors table
ALTER TABLE doctors ADD COLUMN IF NOT EXISTS signature_base64 TEXT;
ALTER TABLE doctors ADD COLUMN IF NOT EXISTS signature_hash TEXT;
