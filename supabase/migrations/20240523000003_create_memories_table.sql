-- Migration to create the memories table for Neuroxus Protocol v1.1
-- This supersedes the documents table.

create table if not exists memories (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  content text not null,
  embedding vector(768),
  source_type text check (source_type in ('user_input', 'file_upload', 'voice_memo')),
  media_url text,
  metadata jsonb default '{}'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Index for vector search
create index if not exists memories_embedding_idx on memories using ivfflat (embedding vector_cosine_ops)
with (lists = 100);

-- Enable RLS
alter table memories enable row level security;

-- RLS Policies
drop policy if exists "Users can insert their own memories" on memories;
create policy "Users can insert their own memories"
on memories for insert
with check (auth.uid() = user_id);

drop policy if exists "Users can select their own memories" on memories;
create policy "Users can select their own memories"
on memories for select
using (auth.uid() = user_id);

drop policy if exists "Users can update their own memories" on memories;
create policy "Users can update their own memories"
on memories for update
using (auth.uid() = user_id);

drop policy if exists "Users can delete their own memories" on memories;
create policy "Users can delete their own memories"
on memories for delete
using (auth.uid() = user_id);

-- RPC for similarity search (v1.1)
-- Drop existing function to allow return type change if needed
DROP FUNCTION IF EXISTS match_memories(vector, float, int);
DROP FUNCTION IF EXISTS match_memories(vector, double precision, int);

create or replace function match_memories (
  query_embedding vector(768),
  match_threshold float,
  match_count int
)
returns setof memories
language sql
stable
as $$
  select *
  from memories
  where 1 - (memories.embedding <=> query_embedding) > match_threshold
  order by memories.embedding <=> query_embedding
  limit match_count;
$$;
