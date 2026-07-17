-- ====================================================================
-- Universal Enterprise Biometric Platform Schema
-- PostgreSQL + pgvector Extension
-- ====================================================================

-- 1. Enable Vector & UUID Extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. User Profiles Table (Platform Users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    role TEXT DEFAULT 'user',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Universal Identities Table (Employees, Students, Visitors, Customers, Members, Patients)
CREATE TABLE IF NOT EXISTS public.identities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    external_id TEXT UNIQUE, -- Badge ID, Employee ID, Student ID, QR Code, SSN
    domain_type TEXT DEFAULT 'generic', -- 'employee', 'student', 'visitor', 'customer', 'patient'
    biometric_status TEXT DEFAULT 'unregistered', -- 'unregistered', 'enrolled', 'revoked'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Extensible Multi-Modal Biometric Templates Table
CREATE TABLE IF NOT EXISTS public.biometric_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    identity_id UUID NOT NULL REFERENCES public.identities(id) ON DELETE CASCADE,
    modality TEXT NOT NULL DEFAULT 'face', -- 'face', 'fingerprint', 'iris', 'voice'
    embedding vector(512) NOT NULL,
    pose_label TEXT NOT NULL DEFAULT 'frontal', -- 'frontal', 'left', 'right', 'up', 'down'
    quality_score DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    model_version TEXT NOT NULL DEFAULT 'ArcFace',
    brightness DOUBLE PRECISION,
    sharpness DOUBLE PRECISION,
    yaw DOUBLE PRECISION,
    pitch DOUBLE PRECISION,
    roll DOUBLE PRECISION,
    capture_time TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    device_info TEXT,
    camera TEXT,
    enrollment_session_id UUID DEFAULT gen_random_uuid(),
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Biometric Audit Log Table
CREATE TABLE IF NOT EXISTS public.biometric_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID,
    action TEXT NOT NULL, -- e.g., 'ENROLL', 'VERIFY', 'IDENTIFY', 'REVOKE'
    target_identity_id UUID,
    details JSONB DEFAULT '{}'::jsonb,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ====================================================================
-- BACKWARD-COMPATIBILITY VIEWS (Supports Legacy CareSync Applications)
-- ====================================================================

CREATE OR REPLACE VIEW public.patients AS 
SELECT id, user_id, external_id AS qr_code_id, biometric_status, created_at, updated_at 
FROM public.identities;

CREATE OR REPLACE VIEW public.patient_embeddings AS 
SELECT id, identity_id AS patient_id, embedding, pose_label, quality_score, model_version, brightness, sharpness, yaw, pitch, roll, capture_time, device_info, camera, enrollment_session_id, is_active, created_at 
FROM public.biometric_templates;

-- ====================================================================
-- INDEXES
-- ====================================================================

-- Cosine Distance HNSW Index for sub-10ms 512-dimensional vector matching
CREATE INDEX IF NOT EXISTS idx_biometric_templates_vector_hnsw 
ON public.biometric_templates 
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

CREATE INDEX IF NOT EXISTS idx_biometric_templates_identity_id ON public.biometric_templates(identity_id);
CREATE INDEX IF NOT EXISTS idx_biometric_templates_active ON public.biometric_templates(is_active);
CREATE INDEX IF NOT EXISTS idx_identities_user_id ON public.identities(user_id);
CREATE INDEX IF NOT EXISTS idx_identities_external_id ON public.identities(external_id);

-- ====================================================================
-- STORED PROCEDURES / RPC FUNCTIONS
-- ====================================================================

-- 1. Duplicate Enrollment Detection (Preventing multi-identity spoofing)
CREATE OR REPLACE FUNCTION public.detect_duplicate_biometrics(
    p_query_embedding vector(512),
    p_threshold double precision
)
RETURNS TABLE (
    identity_id UUID,
    similarity double precision
) 
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    PERFORM set_config('hnsw.ef_search', '64', true);
    RETURN QUERY
    SELECT 
        bt.identity_id, 
        (1 - (bt.embedding <=> p_query_embedding))::double precision AS similarity
    FROM public.biometric_templates bt
    WHERE bt.is_active = true
      AND (bt.embedding <=> p_query_embedding) < (1.0 - p_threshold)
    LIMIT 1;
END;
$$;

-- 2. Multi-pose Consensus Facial Match Engine (Domain-Agnostic)
CREATE OR REPLACE FUNCTION public.match_identity_by_consensus(
    query_embedding vector(512),
    max_distance double precision,
    match_limit integer DEFAULT 10,
    consensus_strategy text DEFAULT 'max'
)
RETURNS TABLE (
    identity_id UUID,
    external_id TEXT,
    full_name TEXT,
    pose_label TEXT,
    similarity double precision,
    quality_score double precision
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    PERFORM set_config('hnsw.ef_search', '64', true);
    RETURN QUERY
    WITH best_pose_matches AS (
        SELECT
            bt.identity_id,
            bt.pose_label,
            (1 - (bt.embedding <=> query_embedding))::double precision AS similarity,
            bt.quality_score::double precision AS quality_score,
            ROW_NUMBER() OVER(PARTITION BY bt.identity_id ORDER BY bt.embedding <=> query_embedding ASC) as rn
        FROM biometric_templates bt
        WHERE bt.model_version = 'ArcFace'
          AND bt.is_active = true
          AND (bt.embedding <=> query_embedding) <= max_distance
    )
    SELECT
        i.id AS identity_id,
        i.external_id,
        COALESCE(prof.full_name, 'Anonymous Subject') AS full_name,
        bpm.pose_label,
        bpm.similarity,
        bpm.quality_score
    FROM best_pose_matches bpm
    JOIN identities i ON bpm.identity_id = i.id
    LEFT JOIN profiles prof ON i.user_id = prof.id
    WHERE bpm.rn = 1
    ORDER BY bpm.similarity DESC
    LIMIT match_limit;
END;
$$;

-- Alias for Backward Compatibility with Legacy CareSync RPC Calls
CREATE OR REPLACE FUNCTION public.match_patient_by_face_consensus(
    query_embedding vector(512),
    max_distance double precision,
    match_limit integer DEFAULT 10,
    consensus_strategy text DEFAULT 'max'
)
RETURNS TABLE (
    patient_id UUID,
    qr_code_id TEXT,
    full_name TEXT,
    pose_label TEXT,
    similarity double precision,
    quality_score double precision
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT identity_id AS patient_id, external_id AS qr_code_id, full_name, pose_label, similarity, quality_score
    FROM public.match_identity_by_consensus(query_embedding, max_distance, match_limit, consensus_strategy);
END;
$$;
