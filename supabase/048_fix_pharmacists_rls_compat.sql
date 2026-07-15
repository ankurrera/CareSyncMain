-- Drop existing policies to prevent conflicts
DROP POLICY IF EXISTS "Pharmacists can manage their own details" ON public.pharmacists;
DROP POLICY IF EXISTS "Anyone can view pharmacist details" ON public.pharmacists;

-- Create a robust, scope-compatible policy allowing users to manage their own records
CREATE POLICY "Pharmacists can manage their own details"
    ON public.pharmacists FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Allow viewing pharmacist details
CREATE POLICY "Anyone can view pharmacist details"
    ON public.pharmacists FOR SELECT
    USING (TRUE);
