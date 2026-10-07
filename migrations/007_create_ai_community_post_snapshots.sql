-- Stores privacy-safe, public-facing summaries for AI-generated community posts.
-- This avoids exposing raw user-entered content directly on public community surfaces.

CREATE TABLE IF NOT EXISTS ai_community_post_snapshots (
  post_id UUID PRIMARY KEY REFERENCES posts(id) ON DELETE CASCADE,
  public_title VARCHAR(300) NOT NULL,
  public_summary TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_community_post_snapshots_updated
  ON ai_community_post_snapshots(updated_at DESC);
