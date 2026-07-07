-- CareSync Biometric Model Versioning
-- Migration 033: Add model version tracking columns to prevent silent vector incompatibility issues

ALTER TABLE public.patient_embeddings 
ADD COLUMN IF NOT EXISTS model_version TEXT NOT NULL DEFAULT 'ArcFace';

ALTER TABLE public.patients 
ADD COLUMN IF NOT EXISTS face_centroid_version TEXT NOT NULL DEFAULT 'ArcFace';
