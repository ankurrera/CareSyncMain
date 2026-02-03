-- CareSync Messaging Schema
-- Run this in your Supabase SQL Editor

-- ============================================================================
-- CHAT ROOMS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS chat_rooms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    doctor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    last_message_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(patient_id, doctor_id)
);

-- ============================================================================
-- MESSAGES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL, -- Encrypted string (Base64)
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================================
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- CHAT ROOMS POLICIES
CREATE POLICY "Participants can view their chat rooms"
    ON chat_rooms FOR SELECT
    USING (auth.uid() = patient_id OR auth.uid() = doctor_id);

CREATE POLICY "Participants can create chat rooms"
    ON chat_rooms FOR INSERT
    WITH CHECK (auth.uid() = patient_id OR auth.uid() = doctor_id);

-- MESSAGES POLICIES
CREATE POLICY "Participants can view room messages"
    ON messages FOR SELECT
    USING (
        room_id IN (
            SELECT id FROM chat_rooms 
            WHERE patient_id = auth.uid() OR doctor_id = auth.uid()
        )
    );

CREATE POLICY "Participants can send messages"
    ON messages FOR INSERT
    WITH CHECK (
        sender_id = auth.uid() AND
        room_id IN (
            SELECT id FROM chat_rooms 
            WHERE patient_id = auth.uid() OR doctor_id = auth.uid()
        )
    );

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_messages_room ON messages(room_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);
CREATE INDEX IF NOT EXISTS idx_rooms_patient ON chat_rooms(patient_id);
CREATE INDEX IF NOT EXISTS idx_rooms_doctor ON chat_rooms(doctor_id);
