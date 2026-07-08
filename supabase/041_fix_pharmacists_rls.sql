-- Migration 041: Fix Pharmacists Table RLS policies for writes
-- ============================================================================

-- Drop existing write/manage policies if they exist to avoid duplication
DROP POLICY IF EXISTS "Pharmacists can manage their own details" ON public.pharmacists;
DROP POLICY IF EXISTS "Anyone can view pharmacist details" ON public.pharmacists;

-- Create policy to allow authenticated pharmacist users to manage (INSERT/UPDATE/DELETE) their own records
CREATE POLICY "Pharmacists can manage their own details"
ON public.pharmacists FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Create policy to allow authenticated users to view pharmacist details (e.g., when viewing dispensing records)
CREATE POLICY "Anyone can view pharmacist details"
ON public.pharmacists FOR SELECT
USING (TRUE);
