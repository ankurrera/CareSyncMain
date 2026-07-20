-- ====================================================================
-- Zero-Data-Loss Migration Script: CareSync v3 -> Universal Platform v4
-- ====================================================================

BEGIN;

-- 1. Safely rename tables (Idempotent)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'patients'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'identities'
    ) THEN
        ALTER TABLE public.patients RENAME TO identities;
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'patient_embeddings'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'biometric_templates'
    ) THEN
        ALTER TABLE public.patient_embeddings RENAME TO biometric_templates;
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'biometric_access_logs'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'biometric_audit_logs'
    ) THEN
        ALTER TABLE public.biometric_access_logs RENAME TO biometric_audit_logs;
    END IF;
END $$;

-- 2. Safely rename columns & add domain/modality extensibility (Idempotent)
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'identities' AND column_name = 'qr_code_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'identities' AND column_name = 'external_id'
    ) THEN
        ALTER TABLE public.identities RENAME COLUMN qr_code_id TO external_id;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'biometric_templates' AND column_name = 'patient_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'biometric_templates' AND column_name = 'identity_id'
    ) THEN
        ALTER TABLE public.biometric_templates RENAME COLUMN patient_id TO identity_id;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'biometric_audit_logs' AND column_name = 'target_patient_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'biometric_audit_logs' AND column_name = 'target_identity_id'
    ) THEN
        ALTER TABLE public.biometric_audit_logs RENAME COLUMN target_patient_id TO target_identity_id;
    END IF;
END $$;

ALTER TABLE public.identities ADD COLUMN IF NOT EXISTS domain_type TEXT DEFAULT 'generic';
ALTER TABLE public.biometric_templates ADD COLUMN IF NOT EXISTS modality TEXT DEFAULT 'face';
ALTER TABLE public.biometric_templates ADD COLUMN IF NOT EXISTS yaw DOUBLE PRECISION;
ALTER TABLE public.biometric_templates ADD COLUMN IF NOT EXISTS pitch DOUBLE PRECISION;
ALTER TABLE public.biometric_templates ADD COLUMN IF NOT EXISTS roll DOUBLE PRECISION;

-- 3. Create Backward-Compatibility Views for Legacy CareSync Applications
CREATE OR REPLACE VIEW public.patients AS 
SELECT id, user_id, external_id AS qr_code_id, biometric_status, created_at, updated_at 
FROM public.identities;

CREATE OR REPLACE VIEW public.patient_embeddings AS 
SELECT id, identity_id AS patient_id, embedding, pose_label, quality_score, model_version, brightness, sharpness, yaw, pitch, roll, capture_time, device_info, camera, enrollment_session_id, is_active, created_at 
FROM public.biometric_templates;

CREATE OR REPLACE VIEW public.biometric_access_logs AS 
SELECT *, target_identity_id AS target_patient_id
FROM public.biometric_audit_logs;

-- 4. Re-create RPC functions (Drop old versions first to allow return type changes)
DROP FUNCTION IF EXISTS public.detect_duplicate_biometrics(vector, double precision);
DROP FUNCTION IF EXISTS public.detect_duplicate_biometrics(vector(512), double precision);

CREATE OR REPLACE FUNCTION public.detect_duplicate_biometrics(
    p_query_embedding vector(512),
    p_threshold double precision
)
RETURNS TABLE (
    patient_id UUID,
    identity_id UUID,
    similarity double precision
) 
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    PERFORM set_config('hnsw.ef_search', '64', true);
    RETURN QUERY
    SELECT 
        bt.identity_id AS patient_id, 
        bt.identity_id, 
        (1 - (bt.embedding <=> p_query_embedding))::double precision AS similarity
    FROM public.biometric_templates bt
    WHERE bt.is_active = true
      AND (bt.embedding <=> p_query_embedding) < (1.0 - p_threshold)
    LIMIT 1;
END;
$$;

DROP FUNCTION IF EXISTS public.match_identity_by_consensus(vector, double precision, integer, text);
DROP FUNCTION IF EXISTS public.match_identity_by_consensus(vector(512), double precision, integer, text);

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
LANGUAGE plpgsql SECURITY DEFINER AS $$
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

DROP FUNCTION IF EXISTS public.match_patient_by_face_consensus(vector, double precision, integer, text);
DROP FUNCTION IF EXISTS public.match_patient_by_face_consensus(vector(512), double precision, integer, text);

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

COMMIT;
