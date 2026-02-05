-- NEUROXUS DATABASE RE-ARCHITECTING (Stage 4 Readiness)
-- Migrates schema to support 'Judgment Marketplace', Traceability, and Advanced Reasoning.

-- 0. Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- 1. Table: documents (Original Source Repository)
-- Holds the raw source material before chunking.
-- IMPORTANT: DROP existing table to enforce new schema (UUID id) if legacy exists (BIGINT id)
DROP TABLE IF EXISTS documents CASCADE;

CREATE TABLE documents (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  title TEXT NOT NULL DEFAULT 'Untitled',
  source_type TEXT CHECK (source_type IN ('Paper', 'Log', 'Web', 'Other')) DEFAULT 'Log',
  raw_content TEXT, -- Full original text
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS for documents
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own documents" ON documents;
CREATE POLICY "Users can manage their own documents" ON documents
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);


-- 2. Table: memories (Smart Chunking & Core Logic Storage)
-- Supersedes previous 'memories' structure.
-- IMPORTANT: DROP existing table to enforce new schema with document_id and judgment_logic
DROP TABLE IF EXISTS memories CASCADE;

CREATE TABLE memories (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  document_id UUID REFERENCES documents(id) ON DELETE CASCADE, -- Traceability to source
  content TEXT NOT NULL, -- Chunked text
  embedding vector(768), -- Gemini 3.0 compatible

  -- Context & Analysis
  metadata JSONB DEFAULT '{}'::jsonb,
  -- Expected keys: section_type, chunk_index, entities (List), sentiment_score

  -- Stage 4: Judgment Logic & Marketplace
  judgment_logic JSONB DEFAULT '{}'::jsonb, -- The "Thought Algorithm"
  logic_version TEXT DEFAULT 'v1.0',   -- e.g., 'v1.0'
  is_public BOOLEAN DEFAULT FALSE,
  price NUMERIC(12, 2) DEFAULT 0.00,
  logic_signature TEXT, -- Unique identifier for the logic block

  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS for memories
ALTER TABLE memories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own memories" ON memories;
CREATE POLICY "Users can manage their own memories" ON memories
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Marketplace Policy (Stage 4)
DROP POLICY IF EXISTS "Anyone can view public logic" ON memories;
CREATE POLICY "Anyone can view public logic" ON memories
  FOR SELECT USING (is_public = TRUE);

-- Indexes for Scalability
CREATE INDEX IF NOT EXISTS memories_embedding_idx ON memories USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX IF NOT EXISTS memories_document_id_idx ON memories (document_id);
CREATE INDEX IF NOT EXISTS memories_metadata_idx ON memories USING gin (metadata);
CREATE INDEX IF NOT EXISTS memories_judgment_logic_idx ON memories USING gin (judgment_logic);


-- 3. Table: knowledge_graph (Entity Relationships)
-- Supports 'getKnowledgeGraphInsights' feature.
DROP TABLE IF EXISTS knowledge_graph CASCADE; -- Ensure clean recreate if type mismatch

CREATE TABLE knowledge_graph (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  source_memory_id UUID REFERENCES memories(id) ON DELETE CASCADE, -- Traceability to specific chunk

  subject TEXT NOT NULL,
  relation TEXT NOT NULL,
  object TEXT NOT NULL,
  confidence_score FLOAT CHECK (confidence_score >= 0 AND confidence_score <= 1.0),

  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS for knowledge_graph
ALTER TABLE knowledge_graph ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own knowledge graph" ON knowledge_graph;
CREATE POLICY "Users can manage their own knowledge graph" ON knowledge_graph
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Indexes for Graph Traversal
CREATE INDEX IF NOT EXISTS kg_subject_idx ON knowledge_graph (subject);
CREATE INDEX IF NOT EXISTS kg_object_idx ON knowledge_graph (object);
CREATE INDEX IF NOT EXISTS kg_source_memory_idx ON knowledge_graph (source_memory_id);


-- 4. Updated Search Function (Hybrid Search Support)
-- Ensures we can search effectively across the new structure
DROP FUNCTION IF EXISTS match_memories;
CREATE OR REPLACE FUNCTION match_memories (
  query_embedding vector(768),
  match_threshold float,
  match_count int
)
RETURNS TABLE (
  id UUID,
  content TEXT,
  similarity FLOAT,
  metadata JSONB,
  document_id UUID,
  logic_version TEXT,
  created_at TIMESTAMPTZ,
  type TEXT,
  emotion TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    memories.id,
    memories.content,
    1 - (memories.embedding <=> query_embedding) AS similarity,
    memories.metadata,
    memories.document_id,
    memories.logic_version,
    memories.created_at,
    memories.metadata->>'type' AS type,
    memories.metadata->>'emotion' AS emotion
  FROM memories
  WHERE 1 - (memories.embedding <=> query_embedding) > match_threshold
  ORDER BY memories.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
