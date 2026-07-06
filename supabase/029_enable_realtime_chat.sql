-- Enable Supabase Realtime for chat tables
-- Without this, no realtime events are broadcast for inserts/updates/deletes.

-- Add messages table to the realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;

-- Add chat_rooms table so last_message_at updates appear in real time
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_rooms;
