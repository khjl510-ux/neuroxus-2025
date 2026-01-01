-- 1. Create table for Real-time Chat Logs (Granular, High-Frequency)
CREATE TABLE IF NOT EXISTS chat_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  session_id UUID NOT NULL, -- Logical grouping for the conversation session
  role TEXT NOT NULL, -- 'user', 'ai'
  content TEXT, -- The raw message
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS for chat_logs
ALTER TABLE chat_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own chat logs" ON chat_logs;
CREATE POLICY "Users can manage their own chat logs" ON chat_logs
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Index for fast retrieval by session
CREATE INDEX IF NOT EXISTS chat_logs_session_idx ON chat_logs (session_id);


-- 2. Update 'documents' table for Session Upsert Support
-- We add 'session_id' to uniquely identify a Session Master Document.
ALTER TABLE documents
ADD COLUMN IF NOT EXISTS session_id UUID;

-- Create a Unique Index to allow ON CONFLICT (user_id, session_id) DO UPDATE
-- This ensures only ONE Master Document exists per Session ID for a User.
CREATE UNIQUE INDEX IF NOT EXISTS documents_user_session_idx ON documents (user_id, session_id);
