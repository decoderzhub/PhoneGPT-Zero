/*
  # Chat Sessions and Messages Schema

  1. New Tables
    - `chat_sessions`
      - `id` (uuid, primary key) - Unique session identifier
      - `title` (text) - Session title (auto-generated from first message)
      - `created_at` (timestamptz) - When session was created
      - `updated_at` (timestamptz) - Last message timestamp
      - `device_id` (text) - Device identifier for multi-device sync
      - `message_count` (integer) - Number of messages in session
      
    - `chat_messages`
      - `id` (uuid, primary key) - Unique message identifier
      - `session_id` (uuid, foreign key) - References chat_sessions
      - `role` (text) - Either 'user' or 'assistant'
      - `content` (text) - Message content
      - `created_at` (timestamptz) - Message timestamp
      - `metadata` (jsonb) - Optional metadata (tokens, sources, etc.)

  2. Security
    - Enable RLS on both tables
    - Public access since this is a local app (no auth required)
    - Add policies for read/write access

  3. Indexes
    - Index on session_id for fast message lookup
    - Index on created_at for chronological ordering
*/

-- Create chat_sessions table
CREATE TABLE IF NOT EXISTS chat_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL DEFAULT 'New Chat',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  device_id text NOT NULL,
  message_count integer DEFAULT 0
);

-- Create chat_messages table
CREATE TABLE IF NOT EXISTS chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('user', 'assistant')),
  content text NOT NULL,
  created_at timestamptz DEFAULT now(),
  metadata jsonb DEFAULT '{}'::jsonb
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_messages_session_id ON chat_messages(session_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON chat_messages(created_at);
CREATE INDEX IF NOT EXISTS idx_sessions_updated_at ON chat_sessions(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_device_id ON chat_sessions(device_id);

-- Enable Row Level Security
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Create policies for public access (local app, no auth)
CREATE POLICY "Allow all operations on chat_sessions"
  ON chat_sessions
  FOR ALL
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow all operations on chat_messages"
  ON chat_messages
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Create function to auto-update updated_at
CREATE OR REPLACE FUNCTION update_chat_session_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE chat_sessions
  SET updated_at = now(),
      message_count = (SELECT COUNT(*) FROM chat_messages WHERE session_id = NEW.session_id)
  WHERE id = NEW.session_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for auto-updating session timestamp
DROP TRIGGER IF EXISTS update_session_on_message ON chat_messages;
CREATE TRIGGER update_session_on_message
  AFTER INSERT ON chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_chat_session_timestamp();
