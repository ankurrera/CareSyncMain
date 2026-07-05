-- CareSync Custom Biometric Vector Schema (ArcFace + pgvector)
-- Run this in your Supabase SQL Editor to enable self-hosted facial recognition

-- ============================================================================
-- 1. ENABLE PGVECTOR EXTENSION
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================================
-- 2. TRANSITION COLUMNS (PURGE AZURE, ADD NATIVE EMBEDDINGS)
-- ============================================================================
-- Clean up Azure references
ALTER TABLE patients DROP COLUMN IF EXISTS azure_person_id;
ALTER TABLE patients DROP COLUMN IF EXISTS azure_persisted_face_id;

-- Add native biometric search columns
ALTER TABLE patients ADD COLUMN IF NOT EXISTS face_scan_url TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS face_embedding vector(512); -- ArcFace generates 512-dimension vectors

-- Create HNSW index for high-performance cosine similarity searches
CREATE INDEX IF NOT EXISTS idx_patients_face_embedding 
ON patients USING hnsw (face_embedding vector_cosine_ops);

-- ============================================================================
-- 3. CREATE MATCH PATIENT BY FACE RPC FUNCTION
-- ============================================================================
CREATE OR REPLACE FUNCTION match_patient_by_face(
    query_embedding vector(512),
    max_distance double precision
)
RETURNS TABLE (
    id UUID,
    qr_code_id TEXT,
    full_name TEXT,
    similarity double precision
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.qr_code_id,
        prof.full_name,
        (1 - (p.face_embedding <=> query_embedding))::double precision AS similarity
    FROM patients p
    JOIN profiles prof ON p.user_id = prof.id
    WHERE p.face_embedding IS NOT NULL
      AND (p.face_embedding <=> query_embedding) <= max_distance
    ORDER BY p.face_embedding <=> query_embedding ASC
    LIMIT 1;
END;
$$;
