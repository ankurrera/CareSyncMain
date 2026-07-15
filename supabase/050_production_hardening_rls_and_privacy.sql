-- Migration 050: CareSync Production Hardening RLS and Privacy Policies
-- Hardens data isolation, drops permissive SELECT rules, and adds secure audit logging.

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. REMOVE PERMISSIVE RLS POLICIES
-- ═══════════════════════════════════════════════════════════════════════════

-- Patients
DROP POLICY IF EXISTS "Patients can view and update their own data" ON public.patients;
DROP POLICY IF EXISTS "Doctors can view patient data" ON public.patients;
DROP POLICY IF EXISTS "Pharmacists can view patient data" ON public.patients;
DROP POLICY IF EXISTS "patients_emergency_view" ON public.patients;

-- Vitals
DROP POLICY IF EXISTS "Patients can manage their own vitals" ON public.vitals;
DROP POLICY IF EXISTS "Doctors can view patient vitals" ON public.vitals;
DROP POLICY IF EXISTS "First responders can view vitals in emergency" ON public.vitals;

-- Medical Conditions
DROP POLICY IF EXISTS "Patients can manage their medical conditions" ON public.medical_conditions;
DROP POLICY IF EXISTS "Doctors can view patient medical conditions" ON public.medical_conditions;
DROP POLICY IF EXISTS "medical_conditions_patients_view_public" ON public.medical_conditions;

-- Prescriptions & Items
DROP POLICY IF EXISTS "Patients can view their prescriptions" ON public.prescriptions;
DROP POLICY IF EXISTS "Pharmacists can view prescriptions" ON public.prescriptions;
DROP POLICY IF EXISTS "prescriptions_emergency_view_public" ON public.prescriptions;
DROP POLICY IF EXISTS "Users can view prescription items for accessible prescriptions" ON public.prescription_items;

-- Emergency Audit Logs
DROP POLICY IF EXISTS "Authenticated users can insert emergency access logs" ON public.emergency_access_logs;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. CREATE SECURE, COMPLIANT RLS POLICIES
-- ═══════════════════════════════════════════════════════════════════════════

-- PATIENTS POLICIES
CREATE POLICY "patients_owner_select_update" ON public.patients
    FOR ALL TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "patients_doctor_select" ON public.patients
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND role = 'doctor'
        ) 
        AND (
            EXISTS (
                SELECT 1 FROM public.appointments 
                WHERE doctor_id = auth.uid() 
                  AND patient_id = patients.user_id
            )
            OR EXISTS (
                SELECT 1 FROM public.emergency_access 
                WHERE requester_id = auth.uid() 
                  AND patient_id = patients.user_id 
                  AND status = 'active' 
                  AND expires_at > NOW()
            )
        )
    );

CREATE POLICY "patients_pharmacist_select" ON public.patients
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND role = 'pharmacist'
        ) 
        AND EXISTS (
            SELECT 1 FROM public.prescriptions 
            WHERE patient_id = patients.id
        )
    );

-- VITALS POLICIES
CREATE POLICY "vitals_owner_all" ON public.vitals
    FOR ALL TO authenticated
    USING (patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid()))
    WITH CHECK (patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid()));

CREATE POLICY "vitals_doctor_select" ON public.vitals
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND role = 'doctor'
        ) 
        AND (
            EXISTS (
                SELECT 1 FROM public.appointments 
                WHERE doctor_id = auth.uid() 
                  AND patient_id = (SELECT user_id FROM public.patients WHERE id = vitals.patient_id)
            )
            OR EXISTS (
                SELECT 1 FROM public.emergency_access 
                WHERE requester_id = auth.uid() 
                  AND patient_id = (SELECT user_id FROM public.patients WHERE id = vitals.patient_id)
                  AND status = 'active' 
                  AND expires_at > NOW()
            )
        )
    );

-- MEDICAL CONDITIONS POLICIES
CREATE POLICY "medical_conditions_owner_all" ON public.medical_conditions
    FOR ALL TO authenticated
    USING (patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid()))
    WITH CHECK (patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid()));

CREATE POLICY "medical_conditions_doctor_select" ON public.medical_conditions
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND role = 'doctor'
        ) 
        AND (
            EXISTS (
                SELECT 1 FROM public.appointments 
                WHERE doctor_id = auth.uid() 
                  AND patient_id = (SELECT user_id FROM public.patients WHERE id = medical_conditions.patient_id)
            )
            OR EXISTS (
                SELECT 1 FROM public.emergency_access 
                WHERE requester_id = auth.uid() 
                  AND patient_id = (SELECT user_id FROM public.patients WHERE id = medical_conditions.patient_id)
                  AND status = 'active' 
                  AND expires_at > NOW()
            )
        )
    );

CREATE POLICY "medical_conditions_public_emergency_select" ON public.medical_conditions
    FOR SELECT TO authenticated
    USING (is_public = TRUE);

-- PRESCRIPTIONS POLICIES
CREATE POLICY "prescriptions_owner_select" ON public.prescriptions
    FOR SELECT TO authenticated
    USING (patient_id IN (SELECT id FROM public.patients WHERE user_id = auth.uid()));

CREATE POLICY "prescriptions_doctor_all" ON public.prescriptions
    FOR ALL TO authenticated
    USING (
        doctor_id = auth.uid()
        OR (
            EXISTS (
                SELECT 1 FROM public.profiles 
                WHERE id = auth.uid() AND role = 'doctor'
            ) 
            AND EXISTS (
                SELECT 1 FROM public.appointments 
                WHERE doctor_id = auth.uid() 
                  AND patient_id = (SELECT user_id FROM public.patients WHERE id = prescriptions.patient_id)
            )
        )
    );

CREATE POLICY "prescriptions_pharmacist_select" ON public.prescriptions
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND role = 'pharmacist'
        )
    );

CREATE POLICY "prescriptions_public_emergency_select" ON public.prescriptions
    FOR SELECT TO authenticated
    USING (is_public = TRUE);

-- PRESCRIPTION ITEMS POLICIES
CREATE POLICY "prescription_items_select" ON public.prescription_items
    FOR SELECT TO authenticated
    USING (
        prescription_id IN (
            SELECT id FROM public.prescriptions
        )
    );

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. SECURE AUDIT LOGGING FUNCTION (SECURITY DEFINER RPC)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.log_emergency_scan_secure(
    p_patient_id UUID,
    p_authentication_method TEXT,
    p_access_status TEXT,
    p_confidence_score DOUBLE PRECISION,
    p_reason_for_access TEXT,
    p_view_scope TEXT,
    p_device_id TEXT,
    p_device_name TEXT,
    p_device_platform TEXT,
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_city TEXT,
    p_state TEXT,
    p_country TEXT,
    p_ip_address TEXT
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_actor_name TEXT;
    v_actor_role TEXT;
BEGIN
    SELECT full_name, role INTO v_actor_name, v_actor_role
    FROM public.profiles
    WHERE id = auth.uid();

    INSERT INTO public.emergency_access_logs (
        patient_id,
        accessed_by_user_id,
        accessed_by_name,
        accessed_by_role,
        authentication_method,
        access_status,
        confidence_score,
        reason_for_access,
        view_scope,
        device_id,
        device_name,
        device_platform,
        latitude,
        longitude,
        city,
        state,
        country,
        ip_address,
        timestamp
    ) VALUES (
        p_patient_id,
        auth.uid(),
        COALESCE(v_actor_name, 'Unknown Provider'),
        COALESCE(v_actor_role, 'unknown'),
        p_authentication_method,
        p_access_status,
        p_confidence_score,
        p_reason_for_access,
        p_view_scope,
        p_device_id,
        p_device_name,
        p_device_platform,
        p_latitude,
        p_longitude,
        p_city,
        p_state,
        p_country,
        p_ip_address,
        NOW()
    );
END;
$$;

REVOKE ALL ON FUNCTION public.log_emergency_scan_secure FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_emergency_scan_secure TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. UPGRADE GET_EMERGENCY_DATA RPC
-- ═══════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.get_emergency_data(TEXT);

CREATE OR REPLACE FUNCTION public.get_emergency_data(p_qr_code_id TEXT)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
    v_patient_id UUID;
BEGIN
    -- 1. Resolve patient ID
    SELECT id INTO v_patient_id
    FROM public.patients
    WHERE qr_code_id = p_qr_code_id;

    IF v_patient_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- 2. Build detailed JSON response
    SELECT jsonb_build_object(
        'patient', jsonb_build_object(
            'id', v_patient_id,
            'full_name', pr.full_name,
            'gender', pr.gender,
            'avatar_url', pr.avatar_url,
            'blood_type', p.blood_type,
            'date_of_birth', p.date_of_birth,
            'weight', p.weight,
            'height', p.height,
            'emergency_contact', p.emergency_contact
        ),
        'conditions', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'type', mc.condition_type,
                    'description', mc.description,
                    'severity', mc.severity
                )
            ), '[]'::jsonb)
            FROM public.medical_conditions mc
            WHERE mc.patient_id = v_patient_id AND mc.is_public = TRUE
        ),
        'medications', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'medicine', pi.medicine_name,
                    'dosage', pi.dosage,
                    'frequency', pi.frequency
                )
            ), '[]'::jsonb)
            FROM public.prescription_items pi
            JOIN public.prescriptions rx ON pi.prescription_id = rx.id
            WHERE rx.patient_id = v_patient_id 
                AND rx.is_public = TRUE 
                AND rx.status = 'active'
        ),
        'vitals', (
            -- Fetch most recent vital reading per type (e.g. weight, blood_pressure)
            WITH latest_vitals AS (
                SELECT DISTINCT ON (type) 
                    type, value, unit, recorded_at
                FROM public.vitals
                WHERE patient_id = v_patient_id
                ORDER BY type, recorded_at DESC
            )
            SELECT COALESCE(jsonb_object_agg(
                type, jsonb_build_object(
                    'value', value,
                    'unit', unit,
                    'recorded_at', recorded_at
                )
            ), '{}'::jsonb)
            FROM latest_vitals
        ),
        'physician', (
            SELECT jsonb_build_object('full_name', d_prof.full_name)
            FROM public.prescriptions rx
            JOIN public.profiles d_prof ON rx.doctor_id = d_prof.id
            WHERE rx.patient_id = v_patient_id
                AND rx.is_public = TRUE
                AND rx.doctor_id IS NOT NULL
            ORDER BY rx.created_at DESC
            LIMIT 1
        )
    ) INTO result
    FROM public.patients p
    JOIN public.profiles pr ON p.user_id = pr.id
    WHERE p.id = v_patient_id;

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE ALL ON FUNCTION public.get_emergency_data FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_emergency_data TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. ADD PERFORMANCE INDEXES
-- ═══════════════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_vitals_patient_recorded ON public.vitals(patient_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_prescriptions_patient_status ON public.prescriptions(patient_id, status);
CREATE INDEX IF NOT EXISTS idx_appointments_patient_status ON public.appointments(patient_id, status);

COMMIT;
