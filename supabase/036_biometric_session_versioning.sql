-- Migration 036: Add versioning and session tracking columns to patient_embeddings table and update RPCs

ALTER TABLE public.patient_embeddings 
ADD COLUMN IF NOT EXISTS brightness double precision,
ADD COLUMN IF NOT EXISTS sharpness double precision,
ADD COLUMN IF NOT EXISTS capture_time timestamp with time zone,
ADD COLUMN IF NOT EXISTS device_info text,
ADD COLUMN IF NOT EXISTS camera text,
ADD COLUMN IF NOT EXISTS enrollment_session_id uuid,
ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true NOT NULL;

-- 1. Recreate detect_duplicate_biometrics with is_active check
CREATE OR REPLACE FUNCTION public.detect_duplicate_biometrics(
    p_query_embedding vector(512),
    p_threshold double precision
)
RETURNS TABLE (
    patient_id UUID,
    similarity double precision
) 
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pe.patient_id, 
        (1 - (pe.embedding <=> p_query_embedding))::double precision AS similarity
    FROM public.patient_embeddings pe
    WHERE pe.is_active = true
      AND (pe.embedding <=> p_query_embedding) < (1.0 - p_threshold)
    LIMIT 1;
END;
$$;

-- 2. Recreate match_patient_by_face_consensus with is_active check
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
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    IF consensus_strategy = 'mean' THEN
        RETURN QUERY
        SELECT
            p.id AS patient_id,
            p.qr_code_id,
            prof.full_name,
            'mean_consensus'::text AS pose_label,
            avg(1 - (pe.embedding <=> query_embedding))::double precision AS similarity,
            avg(pe.quality_score)::double precision AS quality_score
        FROM patient_embeddings pe
        JOIN patients p ON pe.patient_id = p.id
        JOIN profiles prof ON p.user_id = prof.id
        WHERE pe.model_version = 'ArcFace'
          AND pe.is_active = true
        GROUP BY p.id, p.qr_code_id, prof.full_name
        HAVING min(pe.embedding <=> query_embedding) <= max_distance
        ORDER BY similarity DESC
        LIMIT match_limit;
    ELSE
        -- Default/Max strategy: select the single best matching pose vector for each patient
        RETURN QUERY
        WITH best_pose_matches AS (
            SELECT
                pe.patient_id,
                pe.pose_label,
                (1 - (pe.embedding <=> query_embedding))::double precision AS similarity,
                pe.quality_score::double precision AS quality_score,
                ROW_NUMBER() OVER(PARTITION BY pe.patient_id ORDER BY pe.embedding <=> query_embedding ASC) as rn
            FROM patient_embeddings pe
            WHERE pe.model_version = 'ArcFace'
              AND pe.is_active = true
              AND (pe.embedding <=> query_embedding) <= max_distance
        )
        SELECT
            p.id AS patient_id,
            p.qr_code_id,
            prof.full_name,
            bpm.pose_label,
            bpm.similarity,
            bpm.quality_score
        FROM best_pose_matches bpm
        JOIN patients p ON bpm.patient_id = p.id
        JOIN profiles prof ON p.user_id = prof.id
        WHERE bpm.rn = 1
        ORDER BY bpm.similarity DESC
        LIMIT match_limit;
    END IF;
END;
$$;

-- 3. Recreate match_patient_by_face_multi with is_active check
CREATE OR REPLACE FUNCTION public.match_patient_by_face_multi(
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
        WHERE pe.is_active = true
          AND (pe.embedding <=> query_embedding) <= max_distance
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
