-- ============================================================================
-- Migration 031: Fix Doctors Table RLS policies for writes
-- ============================================================================

-- Drop existing write/manage policy if it exists to avoid duplication
DROP POLICY IF EXISTS "Doctors can manage their own details" ON public.doctors;

-- Create policy to allow authenticated doctor users to manage (INSERT/UPDATE/DELETE) their own records
CREATE POLICY "Doctors can manage their own details"
ON public.doctors FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
