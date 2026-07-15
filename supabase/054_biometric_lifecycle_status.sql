-- Migration 054: Add biometric enrollment lifecycle tracking to patients table
ALTER TABLE public.patients 
ADD COLUMN IF NOT EXISTS biometric_status TEXT NOT NULL DEFAULT 'incomplete' 
CHECK (biometric_status IN ('incomplete', 'completed'));

-- Set existing patients who have active embeddings to 'completed'
UPDATE public.patients
SET biometric_status = 'completed'
WHERE id IN (
    SELECT DISTINCT patient_id 
    FROM public.patient_embeddings 
    WHERE is_active = true
);
