-- CareSync Biometric Pose Angles Migration
-- Migration 035: Add yaw, pitch, and roll pose angle columns to patient_embeddings table

ALTER TABLE public.patient_embeddings 
ADD COLUMN IF NOT EXISTS yaw double precision,
ADD COLUMN IF NOT EXISTS pitch double precision,
ADD COLUMN IF NOT EXISTS roll double precision;
