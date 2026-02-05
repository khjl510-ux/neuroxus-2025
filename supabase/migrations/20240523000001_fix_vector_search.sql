-- Enable the pgvector extension to work with embedding vectors
CREATE EXTENSION IF NOT EXISTS vector;

-- Drop the existing function if it exists to ensure we update it correctly
DROP FUNCTION IF EXISTS match_documents;

-- Create the match_documents function for vector similarity search
CREATE OR REPLACE FUNCTION match_documents (
  query_embedding vector(768),
  match_threshold float,
  match_count int
)
RETURNS TABLE (
  id bigint,
  content text,
  metadata jsonb,
  embedding vector(768),
  similarity float,
  created_at timestamptz,
  event_time timestamptz,
  type text,
  emotion text
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    documents.id,
    documents.content,
    documents.metadata, -- Assumes there is a metadata column, remove if not
    documents.embedding,
    1 - (documents.embedding <=> query_embedding) AS similarity,
    documents.created_at,
    documents.event_time,
    documents.type,
    documents.emotion
  FROM documents
  WHERE 1 - (documents.embedding <=> query_embedding) > match_threshold
  ORDER BY documents.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
