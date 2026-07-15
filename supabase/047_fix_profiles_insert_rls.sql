-- Allow authenticated users to insert their own public profile row during registration.
-- This is necessary for client-side upsert actions immediately following sign up.
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;

CREATE POLICY "Users can insert their own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);
