-- 1. Add event_time column if missing
ALTER TABLE documents
ADD COLUMN IF NOT EXISTS event_time TIMESTAMPTZ;

-- 2. Backfill event_time with created_at for existing records
UPDATE documents
SET event_time = created_at
WHERE event_time IS NULL;

-- 3. Create index for performance
CREATE INDEX IF NOT EXISTS documents_event_time_idx ON documents (event_time);

-- 4. Add storage_tier column for protocol compliance
ALTER TABLE documents
ADD COLUMN IF NOT EXISTS storage_tier TEXT DEFAULT 'HOT';

-- 5. Fix Embedding Dimensions for Gemini (768)
-- Check if embedding column exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'embedding') THEN
        -- Alter column type to vector(768)
        -- Note: If data exists with different dimensions, this might fail or require truncation.
        -- Assuming we can reset or alter it.
        ALTER TABLE documents ALTER COLUMN embedding TYPE vector(768);
    ELSE
        -- Create if not exists
        ALTER TABLE documents ADD COLUMN embedding vector(768);
    END IF;
END $$;

-- 6. Reload Schema Cache to fix PGRST204
NOTIFY pgrst, 'reload config';
