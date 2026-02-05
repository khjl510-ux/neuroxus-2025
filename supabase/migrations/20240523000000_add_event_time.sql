-- Add event_time column to documents table
ALTER TABLE documents
ADD COLUMN IF NOT EXISTS event_time TIMESTAMPTZ;

-- Backfill event_time with created_at for existing records
UPDATE documents
SET event_time = created_at
WHERE event_time IS NULL;

-- Create index for performance
CREATE INDEX IF NOT EXISTS documents_event_time_idx ON documents (event_time);

-- Add storage_tier column for protocol compliance
ALTER TABLE documents
ADD COLUMN IF NOT EXISTS storage_tier TEXT DEFAULT 'HOT';

-- Reload Schema Cache
NOTIFY pgrst, 'reload config';
