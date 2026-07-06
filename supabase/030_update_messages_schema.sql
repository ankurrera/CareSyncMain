-- ============================================================================
-- Migration 030: Add is_read and attachment_url to messages
-- ============================================================================

-- 1. Add columns to messages table if they don't exist
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS attachment_url TEXT;

-- 2. Drop existing update policy if it exists to avoid duplication
DROP POLICY IF EXISTS "Participants can update messages to mark as read" ON public.messages;

-- 3. Create update policy for marking messages as read
CREATE POLICY "Participants can update messages to mark as read"
ON public.messages FOR UPDATE
TO authenticated
USING (
    room_id IN (
        SELECT id FROM public.chat_rooms 
        WHERE patient_id = auth.uid() OR doctor_id = auth.uid()
    )
)
WITH CHECK (
    room_id IN (
        SELECT id FROM public.chat_rooms 
        WHERE patient_id = auth.uid() OR doctor_id = auth.uid()
    )
);

-- 4. Set up storage bucket for chat attachments
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat_attachments', 'chat_attachments', true)
ON CONFLICT (id) DO NOTHING;

-- 5. Set up storage security policies
DROP POLICY IF EXISTS "Allow authenticated users to upload chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to view chat attachments" ON storage.objects;

CREATE POLICY "Allow authenticated users to upload chat attachments"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'chat_attachments');

CREATE POLICY "Allow authenticated users to view chat attachments"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'chat_attachments');
