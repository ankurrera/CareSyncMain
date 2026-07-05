-- ============================================================================
-- CareSync: Upgrade match_patient_by_face_multi to use centroid averaging
-- Run this in your Supabase SQL Editor
-- ============================================================================
--
-- STRATEGY: Instead of comparing the query embedding against each pose
-- individually and taking the best pose per patient, this function computes
-- a per-patient CENTROID (average) embedding across all enrolled poses,
-- then compares the query embedding against each centroid.
--
-- WHY THIS IS BETTER:
--   - Averages out per-pose noise, making the reference more robust
--   - Handles angle/lighting variation without extra inference cost
--   - The more poses enrolled, the more accurate and stable the centroid
--   - No change needed to the Flutter app or biometric API enrollment flow

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
    WITH patient_centroids AS (
        -- Compute per-patient centroid embedding by averaging all enrolled pose vectors
        SELECT
            pe.patient_id,
            avg(pe.embedding) AS centroid_embedding,
            avg(pe.quality_score) AS avg_quality,
            count(*)::text AS poses_enrolled
        FROM patient_embeddings pe
        GROUP BY pe.patient_id
    ),
    ranked_matches AS (
        SELECT
            pc.patient_id,
            pc.poses_enrolled,
            pc.avg_quality,
            (pc.centroid_embedding <=> query_embedding)::double precision AS cosine_dist,
            (1 - (pc.centroid_embedding <=> query_embedding))::double precision AS sim
        FROM patient_centroids pc
        WHERE (pc.centroid_embedding <=> query_embedding) <= max_distance
    )
    SELECT
        rm.patient_id,
        p.qr_code_id,
        prof.full_name,
        rm.poses_enrolled AS pose_label,
        rm.sim AS similarity,
        rm.avg_quality AS quality_score
    FROM ranked_matches rm
    JOIN patients p ON rm.patient_id = p.id
    JOIN profiles prof ON p.user_id = prof.id
    ORDER BY rm.sim DESC
    LIMIT match_limit;
END;
$$;
