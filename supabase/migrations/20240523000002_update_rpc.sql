-- Update the match_documents function to support NxsMemory and Hybrid Scoring inputs
-- For now, we just ensure it accepts 768 dim vectors and returns similarity

-- DROP existing function to allow return type change
DROP FUNCTION IF EXISTS match_documents(vector, float, int);
DROP FUNCTION IF EXISTS match_documents(vector, double precision, int);

CREATE OR REPLACE FUNCTION match_documents (
  query_embedding vector(768),
  match_threshold float,
  match_count int
)
RETURNS TABLE (
  id bigint,
  content text,
  similarity float,
  created_at timestamptz,
  event_time timestamptz,
  emotion text,
  type text
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    documents.id,
    documents.content,
    1 - (documents.embedding <=> query_embedding) AS similarity,
    documents.created_at,
    documents.event_time,
    documents.emotion,
    documents.type
  FROM documents
  WHERE 1 - (documents.embedding <=> query_embedding) > match_threshold
  ORDER BY similarity DESC
  LIMIT match_count;
END;
$$;
