-- Fix Row Level Security (RLS) policy for updating KYC data.
-- Drop the old restrictive policy that prevented resubmitting rejected/verified KYC.
DROP POLICY IF EXISTS "Users can update their own pending KYC data" ON kyc_verifications;
DROP POLICY IF EXISTS "Users can update their own KYC data" ON kyc_verifications;

-- Create a new policy allowing users to update their own KYC records regardless of status.
CREATE POLICY "Users can update their own KYC data"
    ON kyc_verifications FOR UPDATE
    USING (auth.uid() = user_id);
