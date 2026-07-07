-- CareSync Biometric Enterprise Upgrade
-- Migration 034: Adds RPCs for duplicate enrollment check and multiple pose consensus matches

-- 1. Duplicate Enrollment Check RPC
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
    WHERE (pe.embedding <=> p_query_embedding) < (1.0 - p_threshold)
    LIMIT 1;
END;
$$;

-- 2. Multi-pose Consensus Matching RPC
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
