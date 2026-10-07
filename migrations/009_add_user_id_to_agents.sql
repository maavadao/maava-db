-- Add direct FK from agents → users so we know which human owns an agent.
ALTER TABLE agents ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_agents_user_id ON agents(user_id) WHERE user_id IS NOT NULL;
