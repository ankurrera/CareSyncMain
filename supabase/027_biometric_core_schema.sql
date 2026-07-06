-- CareSync Biometric Core Schema
-- Migration 027: Centralized Biometric Platform tables, triggers, and security controls
-- Activating the pg_sodium extension for database vault options (if available)

CREATE EXTENSION IF NOT EXISTS "vector";

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. BIOMETRIC PROFILES
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.biometric_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    enrollment_status TEXT NOT NULL DEFAULT 'unverified' CHECK (enrollment_status IN ('unverified', 'verified', 'suspended')),
    liveness_score_threshold DOUBLE PRECISION NOT NULL DEFAULT 0.90,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. FACE EMBEDDINGS
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.face_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    biometric_profile_id UUID NOT NULL REFERENCES public.biometric_profiles(id) ON DELETE CASCADE,
    embedding vector(512) NOT NULL,
    pose_label TEXT NOT NULL CHECK (pose_label IN ('neutral', 'smile', 'angle_left', 'angle_right')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexing for embeddings (HNSW Index for similarity lookups)
CREATE INDEX IF NOT EXISTS idx_face_embeddings_vector 
ON public.face_embeddings USING hnsw (embedding vector_cosine_ops);

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. DEVICE TRUST
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.device_trust (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    device_name TEXT,
    device_os TEXT,
    token_fingerprint_hash TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, device_id)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. BIOMETRIC SESSIONS
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.biometric_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    session_token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    last_activity_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. CONSENT RECORDS
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.consent_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    doctor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    consent_type TEXT NOT NULL CHECK (consent_type IN ('Single Session', 'Scheduled Appointment', 'Ongoing Care', 'Emergency Override')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked', 'expired')),
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    auth_code_hash TEXT
);

CREATE INDEX IF NOT EXISTS idx_consent_active_lookup 
ON public.consent_records(doctor_id, patient_id, status) 
WHERE status = 'active';

-- ═══════════════════════════════════════════════════════════════════════════
-- 6. TEMPORARY ACCESS
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.temporary_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    consent_record_id UUID NOT NULL REFERENCES public.consent_records(id) ON DELETE CASCADE,
    doctor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    decryption_token TEXT NOT NULL, -- Short-lived session token
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_temp_access_lookup 
ON public.temporary_access(doctor_id, patient_id, expires_at);

-- ═══════════════════════════════════════════════════════════════════════════
-- 7. BIOMETRIC ACCESS LOGS (Immutable Audit Log)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.biometric_access_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    actor_name TEXT NOT NULL,
    actor_role TEXT NOT NULL,
    action_type TEXT NOT NULL,
    target_patient_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    hospital_name TEXT,
    department_name TEXT,
    device_id TEXT NOT NULL,
    gps_coordinates TEXT,
    confidence_score DOUBLE PRECISION,
    model_version TEXT,
    status TEXT NOT NULL CHECK (status IN ('SUCCESS', 'FAILURE', 'DENIED', 'EXPIRED')),
    view_scope TEXT,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_access_logs_audit 
ON public.biometric_access_logs(target_patient_id, created_at DESC);

-- Apply row level security (RLS)
ALTER TABLE public.biometric_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.face_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_trust ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biometric_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consent_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.temporary_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biometric_access_logs ENABLE ROW LEVEL SECURITY;

-- Security Policies
CREATE POLICY "Profiles view self" ON public.biometric_profiles FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "System select profiles" ON public.biometric_profiles FOR SELECT TO authenticated USING (true);

CREATE POLICY "Embeddings select auth" ON public.face_embeddings FOR SELECT TO authenticated USING (true);
CREATE POLICY "Embeddings insert self" ON public.face_embeddings FOR INSERT TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM public.biometric_profiles WHERE id = biometric_profile_id AND user_id = auth.uid())
);

CREATE POLICY "Consent check doctor" ON public.consent_records FOR SELECT TO authenticated USING (auth.uid() = doctor_id);
CREATE POLICY "Consent manage patient" ON public.consent_records FOR ALL TO authenticated USING (auth.uid() = patient_id);

CREATE POLICY "Temp access select doc" ON public.temporary_access FOR SELECT TO authenticated USING (auth.uid() = doctor_id);

CREATE POLICY "Logs insert system" ON public.biometric_access_logs FOR INSERT TO authenticated WITH CHECK (auth.uid() = actor_id);
CREATE POLICY "Logs select owner" ON public.biometric_access_logs FOR SELECT TO authenticated USING (auth.uid() = actor_id OR auth.uid() = target_patient_id);

-- Enforce Audit Immutability Trigger
CREATE OR REPLACE FUNCTION public.prevent_audit_changes()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Audit logs are immutable. Modifying records is prohibited.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_prevent_audit_changes
BEFORE UPDATE OR DELETE ON public.biometric_access_logs
FOR EACH ROW
EXECUTE FUNCTION public.prevent_audit_changes();

-- ═══════════════════════════════════════════════════════════════════════════
-- 8. DATABASE FUNCTIONS & RPCS
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.match_patient_by_face(
  p_query_embedding vector(512),
  p_max_distance DOUBLE PRECISION,
  p_limit INTEGER
)
RETURNS TABLE (
  patient_id UUID,
  full_name TEXT,
  similarity DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.user_id AS patient_id,
    p.full_name,
    (1 - (fe.embedding <=> p_query_embedding))::DOUBLE PRECISION AS similarity
  FROM public.face_embeddings fe
  JOIN public.biometric_profiles bp ON fe.biometric_profile_id = bp.id
  JOIN public.profiles p ON bp.user_id = p.id
  WHERE fe.is_active = true
    AND (fe.embedding <=> p_query_embedding) < p_max_distance
  ORDER BY fe.embedding <=> p_query_embedding ASC
  LIMIT p_limit;
END;
$$;
