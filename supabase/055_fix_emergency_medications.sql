-- Migration 055: Fix get_emergency_data to include medications from active, processing, or partially_dispensed prescriptions.

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
                AND rx.status IN ('active', 'processing', 'partially_dispensed')
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
