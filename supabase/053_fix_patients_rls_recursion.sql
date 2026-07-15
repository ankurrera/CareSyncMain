-- Fix infinite recursion in patient/prescription RLS policies.
-- By removing the dependency on public.prescriptions in patients_pharmacist_select,
-- we break the circular reference: patients -> prescriptions -> patients.

DROP POLICY IF EXISTS "patients_pharmacist_select" ON public.patients;

CREATE POLICY "patients_pharmacist_select" ON public.patients
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND role = 'pharmacist'
        )
    );
