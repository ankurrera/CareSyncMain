-- Drop old policies to prevent name clashes
DROP POLICY IF EXISTS "Pharmacists can manage their own details" ON public.pharmacists;
DROP POLICY IF EXISTS "Pharmacists can select their own details" ON public.pharmacists;
DROP POLICY IF EXISTS "Pharmacists can insert their own details" ON public.pharmacists;
DROP POLICY IF EXISTS "Pharmacists can update their own details" ON public.pharmacists;
DROP POLICY IF EXISTS "Pharmacists can delete their own details" ON public.pharmacists;
DROP POLICY IF EXISTS "Anyone can view pharmacist details" ON public.pharmacists;

-- Explicit SELECT policy
CREATE POLICY "Pharmacists can select their own details"
    ON public.pharmacists FOR SELECT
    USING (auth.uid() = user_id);

-- Explicit INSERT policy (handles the insert phase of upsert)
CREATE POLICY "Pharmacists can insert their own details"
    ON public.pharmacists FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Explicit UPDATE policy (handles the update phase of upsert)
CREATE POLICY "Pharmacists can update their own details"
    ON public.pharmacists FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Explicit DELETE policy
CREATE POLICY "Pharmacists can delete their own details"
    ON public.pharmacists FOR DELETE
    USING (auth.uid() = user_id);

-- General view policy
CREATE POLICY "Anyone can view pharmacist details"
    ON public.pharmacists FOR SELECT
    USING (TRUE);
