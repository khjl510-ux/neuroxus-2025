# Neuroxus Technical Implementation Plan (v1.1)

## Overview
Adapting the "Neuroxus Technical Specification v1.1" to the current Flutter + Supabase environment. This document outlines how the 9 Key Pillars will be implemented.

## 1. 4D Coordinate Schema (The `.nxs` Protocol)
Instead of a rigid SQL row, we will use a flexible structure (likely leveraging Supabase `jsonb` or extending the columns) to enforce the 4D index.

**Data Structure (`NxsMemory`):**
*   **UUID**: Unique ID.
*   **Vector**: 768-dim embedding (Phantom Embedding).
*   **Time (`t`)**: UTC Timestamp (Event Time).
*   **Space (`x,y,z`)**:
    *   `x`: Latitude
    *   `y`: Longitude
    *   `z`: Altitude (or semantic location context e.g., "Home", "Office").
*   **Content**: Rich Text (VLM processed).
*   **Tier**: `HOT` (Raw accessible) | `COLD` (Compressed/Archived).

## 2. Text-First & Rich Description
*   **Input**: Image/Audio.
*   **Process**: Gemini Flash 2.5 (VLM/STT) -> Rich Text Description (Sentiment + Atmosphere).
*   **Storage**: Store the *Text* as the primary searchable content. Raw media is secondary.

## 3. Human-in-the-Loop
*   **Flow**:
    1.  User Input -> Temporary State (Draft).
    2.  AI Analysis -> Suggests Tags/Location/Sentiment.
    3.  **UI Interruption**: User validates/edits.
    4.  **Commit**: Save to Supabase `documents` table.

## 4. Phantom Embedding
*   **Logic**: When "deleting" a memory, we only remove the `media_url` or `raw_content` reference.
*   **Persistence**: The `embedding` (vector) and `summary_text` remain in the DB.
*   **Benefit**: Users can search for "that photo I took at the beach" even if the photo file itself was deleted to save space.

## 5. No Deletion & Dual-State
*   **Supabase Implementation**:
    *   Column `is_archived` (Boolean).
    *   Column `storage_tier` (Enum: 'HOT', 'COLD').
*   **Vector Search**: The `match_documents` RPC must query *all* tiers (Hot + Cold).

## 6. Serendipity Logic
*   **Algorithm**: "Contextual Mixing".
*   **Implementation**:
    *   Perform Standard Vector Search (Top K).
    *   Perform "Antagonistic" Search (Vectors *distant* but within specific semantic clusters) or Random Sampling weighted by `Time Decay` (inverse).
    *   Combine results.

## 7. Hybrid Search Scoring
*   **Formula**: $Score = (Vector \cdot 0.5) + (Geo \cdot 0.3) + (TimeDecay \cdot 0.2)$
*   **Supabase RPC**: We need to update `match_documents` to accept `user_lat`, `user_long`, and `current_time` to calculate this composite score inside the database function.

## 8. Session Working Memory (Simulated Redis)
*   **Context**: Since we don't have a Redis instance, we will use an **In-Memory App State (`SessionProvider`)** in Flutter, backed by a temporary Supabase table `session_buffer` if persistence across app restarts is needed.
*   **Flow**:
    1.  Conversation Start -> Init List<NxsMemory> buffer.
    2.  Retrieval -> Add relevant memories to buffer.
    3.  End Session -> Summarize buffer -> Commit to `documents` (Long-term).

## 9. Realistic Optimization
*   **Optimistic UI**: Display the user's input immediately. Show "Analyzing..." spinner for VLM/Embedding metadata.
*   **Hybrid AI**: Use Gemini Flash (Cloud) for heavy lifting. (Future: On-device LLM).

---

## Schema Design (Supabase Mapping)

**Table: `documents` (Existing, to be enhanced)**
| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | UUID | Primary Key |
| `user_id` | UUID | Owner |
| `content` | Text | Rich Text Description |
| `embedding` | Vector(768) | Semantic Key |
| `created_at` | Timestamptz | Time (t) - Record creation |
| `event_time` | Timestamptz | Time (t) - Actual event time (defaults to created_at) |
| `location_lat` | Float8 | Space (x) |
| `location_lon` | Float8 | Space (y) |
| `location_context` | Text | Space (z) - Semantic location |
| `storage_tier` | Text | 'HOT' or 'COLD' |
| `media_url` | Text | Reference to raw file (nullable for Phantom) |
| `emotion` | Text | Sentiment metadata |
| `similarity` | Float8 | (Computed, not stored) |
