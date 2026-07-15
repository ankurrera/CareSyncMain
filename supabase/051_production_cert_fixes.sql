-- ============================================================================
-- Migration 051: Production readiness certification security & isolation fixes
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. TWO FACTOR AUTHENTICATION HARDENING
-- ─────────────────────────────────────────────────────────────────────────────

-- Remove client UPDATE capability to prevent client-side bypasses
DROP POLICY IF EXISTS "Users can update their own 2FA codes" ON public.two_factor_codes;

-- Create SECURE verification RPC function (runs as SECURITY DEFINER with admin privileges)
CREATE OR REPLACE FUNCTION public.verify_two_factor_code(
    p_user_id UUID,
    p_code TEXT,
    p_code_type TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_code_id UUID;
    v_stored_code TEXT;
    v_expires_at TIMESTAMPTZ;
    v_attempts INT;
BEGIN
    -- Security Check: The caller must be the owner of the 2FA code
    IF auth.uid() IS DISTINCT FROM p_user_id THEN
        RAISE EXCEPTION 'Unauthorized 2FA verification request';
    END IF;

    -- Retrieve the most recent unverified code
    SELECT id, code, expires_at, attempts INTO v_code_id, v_stored_code, v_expires_at, v_attempts
    FROM public.two_factor_codes
    WHERE user_id = p_user_id
      AND code_type = p_code_type
      AND verified = FALSE
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_code_id IS NULL THEN
        RAISE EXCEPTION 'No verification code found';
    END IF;

    -- Validate expiration
    IF NOW() > v_expires_at THEN
        RAISE EXCEPTION 'Verification code has expired';
    END IF;

    -- Validate attempts
    IF v_attempts >= 3 THEN
        RAISE EXCEPTION 'Maximum verification attempts exceeded';
    END IF;

    -- Verify code match
    IF p_code = v_stored_code THEN
        UPDATE public.two_factor_codes
        SET verified = TRUE,
            verified_at = NOW()
        WHERE id = v_code_id;

        -- Write secure audit log
        INSERT INTO public.audit_log (user_id, action, resource_type, resource_id, timestamp)
        VALUES (p_user_id, 'twoFactorVerified', 'two_factor_code', v_code_id, NOW());

        RETURN TRUE;
    ELSE
        -- Increment attempts count
        UPDATE public.two_factor_codes
        SET attempts = attempts + 1
        WHERE id = v_code_id;

        RAISE EXCEPTION 'Invalid verification code';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. CLINICAL RECORDS HARDENING (DOCTOR RLS)
-- ─────────────────────────────────────────────────────────────────────────────

-- Remove weak SELECT policy for doctors on medical records
DROP POLICY IF EXISTS "Doctors can view medical records" ON public.medical_records;

-- Implement strict doctor access RLS check: Doctor must have active appointment OR active emergency session
CREATE POLICY "Doctors can view medical records"
    ON public.medical_records FOR SELECT
    TO authenticated
    USING (
        -- User has the role doctor
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND role = 'doctor'
        )
        AND (
            -- Treatment Relationship: doctor has a scheduled/confirmed/completed appointment with the patient
            EXISTS (
                SELECT 1 FROM public.appointments 
                WHERE doctor_id = auth.uid() 
                  AND patient_id = medical_records.user_id
                  AND status IN ('scheduled', 'completed', 'active')
            )
            -- Emergency Bypass: doctor has an active, unexpired emergency override session for the patient
            OR EXISTS (
                SELECT 1 FROM public.emergency_access 
                WHERE requester_id = auth.uid() 
                  AND patient_id = medical_records.user_id 
                  AND status = 'active' 
                  AND expires_at > NOW()
            )
        )
    );

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. EMERGENCY ACCESS PROTECTION (SESSION HIJACK PREVENTER)
-- ─────────────────────────────────────────────────────────────────────────────

-- Drop existing revoke policy
DROP POLICY IF EXISTS "Users can revoke their own emergency access" ON public.emergency_access;

-- Re-create revoke policy purely for status revocation
CREATE POLICY "Users can revoke their own emergency access"
    ON public.emergency_access FOR UPDATE
    TO authenticated
    USING (auth.uid() = requester_id)
    WITH CHECK (auth.uid() = requester_id);

-- Enforce strict immutability on emergency sessions using trigger
CREATE OR REPLACE FUNCTION public.check_emergency_access_immutability()
RETURNS TRIGGER AS $$
BEGIN
    -- Block modifications of critical columns
    IF OLD.requester_id IS DISTINCT FROM NEW.requester_id OR
       OLD.requester_role IS DISTINCT FROM NEW.requester_role OR
       OLD.patient_id IS DISTINCT FROM NEW.patient_id OR
       OLD.reason IS DISTINCT FROM NEW.reason OR
       OLD.additional_notes IS DISTINCT FROM NEW.additional_notes OR
       OLD.granted_at IS DISTINCT FROM NEW.granted_at OR
       OLD.expires_at IS DISTINCT FROM NEW.expires_at OR
       OLD.biometric_verified IS DISTINCT FROM NEW.biometric_verified OR
       OLD.created_at IS DISTINCT FROM NEW.created_at THEN
        RAISE EXCEPTION 'Emergency access session parameters are immutable. Only status revocation is allowed.';
    END IF;

    -- Verify that transition is valid (e.g. only active can transition to revoked or expired)
    IF OLD.status = 'active' AND NEW.status NOT IN ('revoked', 'expired') THEN
        RAISE EXCEPTION 'Invalid status transition for emergency access session.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_check_emergency_access_immutability ON public.emergency_access;
CREATE TRIGGER trigger_check_emergency_access_immutability
    BEFORE UPDATE ON public.emergency_access
    FOR EACH ROW
    EXECUTE FUNCTION public.check_emergency_access_immutability();

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. AUDIT TRAIL HARDENING
-- ─────────────────────────────────────────────────────────────────────────────

-- Remove insecure insert policy from the audit log table
DROP POLICY IF EXISTS "System can insert audit logs" ON public.audit_log;

-- Secure Audit Insertion RPC (Populates auth.uid() automatically inside database context)
CREATE OR REPLACE FUNCTION public.log_audit_action_secure(
    p_action TEXT,
    p_resource_type TEXT,
    p_resource_id UUID,
    p_device_id TEXT,
    p_ip_address TEXT,
    p_user_agent TEXT,
    p_metadata JSONB
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.audit_log (
        user_id,
        action,
        resource_type,
        resource_id,
        device_id,
        ip_address,
        user_agent,
        metadata,
        timestamp
    ) VALUES (
        auth.uid(),
        p_action,
        p_resource_type,
        p_resource_id,
        p_device_id,
        p_ip_address,
        p_user_agent,
        p_metadata,
        NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. PRESCRIPTION STORAGE BUCKET ISOLATION (STORAGE RLS)
-- ─────────────────────────────────────────────────────────────────────────────

-- Ensure prescriptions bucket has policies
DROP POLICY IF EXISTS "prescriptions_storage_select" ON storage.objects;
CREATE POLICY "prescriptions_storage_select" ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'prescriptions'
    AND (
        -- User is doctor
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'doctor')
        OR
        -- User is pharmacist
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'pharmacist')
        OR
        -- User is patient themselves (checking profile ID prefix on filename or folder)
        (
            (storage.foldername(name))[1] = auth.uid()::text
            OR name LIKE auth.uid()::text || '%'
            OR EXISTS (
                SELECT 1 FROM public.patients p
                WHERE p.user_id = auth.uid()
                  AND name LIKE p.id::text || '%'
            )
        )
    )
);

DROP POLICY IF EXISTS "prescriptions_storage_insert" ON storage.objects;
CREATE POLICY "prescriptions_storage_insert" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'prescriptions'
    AND (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('doctor', 'patient'))
    )
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. PERFORMANCE INDEXES
-- ─────────────────────────────────────────────────────────────────────────────

-- Composite Index to optimize RLS appointment verification checks
CREATE INDEX IF NOT EXISTS idx_appointments_relationship 
ON public.appointments(doctor_id, patient_id, status);
