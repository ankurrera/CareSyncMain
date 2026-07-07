-- Migration 039: Define secure submit RPC for KYC and restrict direct client updates on status

-- 1. Create secure submit RPC running as SECURITY DEFINER (db owner/service role context)
CREATE OR REPLACE FUNCTION public.submit_kyc_secure(
    p_full_name TEXT,
    p_date_of_birth DATE,
    p_id_document_url TEXT,
    p_selfie_url TEXT,
    p_additional_documents TEXT[]
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.kyc_verifications (
        user_id,
        full_name,
        date_of_birth,
        id_document_url,
        selfie_url,
        additional_documents,
        kyc_status,
        created_at,
        updated_at
    )
    VALUES (
        auth.uid(),
        p_full_name,
        p_date_of_birth,
        p_id_document_url,
        p_selfie_url,
        p_additional_documents,
        'verified', -- Auto-approved server-side
        NOW(),
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE
    SET
        full_name = EXCLUDED.full_name,
        date_of_birth = EXCLUDED.date_of_birth,
        id_document_url = EXCLUDED.id_document_url,
        selfie_url = EXCLUDED.selfie_url,
        additional_documents = EXCLUDED.additional_documents,
        kyc_status = 'verified',
        updated_at = NOW();
END;
$$;

-- 2. Restrict update RLS policy so the client cannot directly verify their own record
DROP POLICY IF EXISTS "Users can update their own KYC data" ON kyc_verifications;
CREATE POLICY "Users can update their own KYC data"
    ON kyc_verifications FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id AND (kyc_status = 'pending' OR kyc_status IS NULL));
