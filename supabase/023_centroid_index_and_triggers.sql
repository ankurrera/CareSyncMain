-- ============================================================================
-- CareSync: Centroid Index and Triggers for Facial Biometrics
-- ============================================================================
-- 1. ADD CENTROID COLUMN TO PATIENTS
-- ============================================================================
ALTER TABLE patients ADD COLUMN IF NOT EXISTS face_centroid_embedding vector(512);

-- ============================================================================
-- 2. CREATE HNSW INDEX FOR SPEEDY COSINE SEARCHES ON CENTROIDS
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_patients_face_centroid_embedding 
ON patients USING hnsw (face_centroid_embedding vector_cosine_ops);

-- ============================================================================
-- 3. TRIGGER FUNCTION TO AUTOMATICALLY UPDATE CENTROID ON POSE ENROLLMENT
-- ============================================================================
CREATE OR REPLACE FUNCTION update_patient_face_centroid()
RETURNS TRIGGER AS $$
DECLARE
    avg_vector vector(512);
    target_patient_id UUID;
BEGIN
    -- Determine which patient_id needs recalculation
    IF TG_OP = 'DELETE' THEN
        target_patient_id := OLD.patient_id;
    ELSE
        target_patient_id := NEW.patient_id;
    END IF;

    -- Calculate the average vector of all poses for this patient
    SELECT avg(embedding)
    INTO avg_vector
    FROM patient_embeddings
    WHERE patient_id = target_patient_id;

    -- Update the patients table with the new centroid
    UPDATE patients
    SET face_centroid_embedding = avg_vector,
        updated_at = now()
    WHERE id = target_patient_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. ATTACH TRIGGER TO PATIENT EMBEDDINGS
-- ============================================================================
DROP TRIGGER IF EXISTS trg_update_patient_face_centroid ON patient_embeddings;

CREATE TRIGGER trg_update_patient_face_centroid
AFTER INSERT OR UPDATE OR DELETE ON patient_embeddings
FOR EACH ROW
EXECUTE FUNCTION update_patient_face_centroid();

-- ============================================================================
-- 5. RUN ONE-TIME MIGRATION TO CALCULATE EXISTNG PATIENT CENTROIDS
-- ============================================================================
UPDATE patients p
SET face_centroid_embedding = (
    SELECT avg(pe.embedding)
    FROM patient_embeddings pe
    WHERE pe.patient_id = p.id
)
WHERE EXISTS (
    SELECT 1 
    FROM patient_embeddings pe 
    WHERE pe.patient_id = p.id
);

-- ============================================================================
-- 6. REWRITE THE FACE IDENTIFICATION RPC MATCHING FUNCTION
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
    SELECT
        p.id AS patient_id,
        p.qr_code_id,
        prof.full_name,
        'centroid'::text AS pose_label,
        (1 - (p.face_centroid_embedding <=> query_embedding))::double precision AS similarity,
        1.0::double precision AS quality_score
    FROM patients p
    JOIN profiles prof ON p.user_id = prof.id
    WHERE p.face_centroid_embedding IS NOT NULL
      AND (p.face_centroid_embedding <=> query_embedding) <= max_distance
    ORDER BY p.face_centroid_embedding <=> query_embedding ASC
    LIMIT match_limit;
END;
$$;
