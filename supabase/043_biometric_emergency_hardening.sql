-- Migration 043: Hardening biometric and emergency flows

-- 1. Update get_emergency_data to return patient_id at the top level
DROP FUNCTION IF EXISTS public.get_emergency_data(TEXT);
CREATE OR REPLACE FUNCTION public.get_emergency_data(p_qr_code_id TEXT)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'patient_id', p.id,
        'patient', jsonb_build_object(
            'full_name', pr.full_name,
            'blood_type', p.blood_type,
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
            FROM medical_conditions mc
            WHERE mc.patient_id = p.id AND mc.is_public = TRUE
        ),
        'medications', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'medicine', pi.medicine_name,
                    'dosage', pi.dosage,
                    'frequency', pi.frequency
                )
            ), '[]'::jsonb)
            FROM prescription_items pi
            JOIN prescriptions rx ON pi.prescription_id = rx.id
            WHERE rx.patient_id = p.id 
                AND rx.is_public = TRUE 
                AND rx.status = 'active'
        )
    ) INTO result
    FROM patients p
    JOIN profiles pr ON p.user_id = pr.id
    WHERE p.qr_code_id = p_qr_code_id;

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Revoke public/anon execute privilege on face-matching RPCs
REVOKE EXECUTE ON FUNCTION public.match_patient_by_face(vector, double precision, integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.match_patient_by_face_multi(vector, double precision, integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.match_patient_by_face_consensus(vector, double precision, integer, text) FROM PUBLIC, anon;

-- Ensure authenticated and service_role retain EXECUTE rights
GRANT EXECUTE ON FUNCTION public.match_patient_by_face(vector, double precision, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.match_patient_by_face_multi(vector, double precision, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.match_patient_by_face_consensus(vector, double precision, integer, text) TO authenticated, service_role;

-- 3. Restrict profiles policies to authenticated users only (remove anon select)
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Public profiles are viewable by everyone"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (TRUE);

DROP POLICY IF EXISTS "profiles_emergency_view" ON public.profiles;
CREATE POLICY "profiles_emergency_view"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (role = 'patient');
