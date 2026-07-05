-- CareSync Multi-Embedding Database Schema (ArcFace + pgvector)
-- Run this in your Supabase SQL Editor

-- ============================================================================
-- 1. CREATE PATIENT EMBEDDINGS TABLE FOR MULTI-POSE ENROLLMENT
-- ============================================================================
CREATE TABLE IF NOT EXISTS patient_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    embedding vector(512) NOT NULL,
    pose_label TEXT NOT NULL, -- e.g., 'neutral', 'smile', 'left_30', 'right_30', 'glasses', 'no_glasses', 'low_light'
    quality_score double precision DEFAULT 1.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create HNSW index for high-performance vector searches on the embeddings table
CREATE INDEX IF NOT EXISTS idx_patient_embeddings_vector 
ON patient_embeddings USING hnsw (embedding vector_cosine_ops);

-- Index for patient lookups
CREATE INDEX IF NOT EXISTS idx_patient_embeddings_patient_id 
ON patient_embeddings(patient_id);

-- ============================================================================
-- 2. CREATE SMART MULTI-EMBEDDING MATCHING FUNCTION
-- ============================================================================
CREATE OR REPLACE FUNCTION match_patient_by_face_multi(
    query_embedding vector(512),
    max_distance double precision,
    match_limit integer DEFAULT 10
)
RETURNS TABLE (
    patient_id UUID,
    qr_code_id TEXT,
    full_name TEXT,
    pose_label TEXT,
    similarity double precision,
    quality_score double precision
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH nearest_matches AS (
        SELECT 
            pe.patient_id,
            pe.pose_label,
            pe.quality_score,
            (1 - (pe.embedding <=> query_embedding))::double precision AS sim,
            ROW_NUMBER() OVER (PARTITION BY pe.patient_id ORDER BY pe.embedding <=> query_embedding ASC) as rank
        FROM patient_embeddings pe
        WHERE (pe.embedding <=> query_embedding) <= max_distance
    )
    SELECT
        nm.patient_id,
        p.qr_code_id,
        prof.full_name,
        nm.pose_label,
        nm.sim AS similarity,
        nm.quality_score
    FROM nearest_matches nm
    JOIN patients p ON nm.patient_id = p.id
    JOIN profiles prof ON p.user_id = prof.id
    WHERE nm.rank = 1  -- Return the best matching pose/embedding per patient
    ORDER BY nm.sim DESC
    LIMIT match_limit;
END;
$$;
