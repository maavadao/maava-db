-- Migration 010: SOUL/SKILL/HEARTBEAT/CHANNEL Agent Architecture
-- Adds tables for full agent configuration, user installations, and task execution

-- ============================================================================
-- 1. AGENT_CONFIGS — SOUL + SKILL + HEARTBEAT + CHANNEL definitions per agent
-- ============================================================================
-- Each marketplace_agent can have full SOUL/SKILL/HEARTBEAT/CHANNEL config stored as JSONB.
-- This makes agents actually functional (not just catalog entries).

ALTER TABLE marketplace_agents ADD COLUMN IF NOT EXISTS soul_config JSONB DEFAULT '{}'::jsonb;
ALTER TABLE marketplace_agents ADD COLUMN IF NOT EXISTS skills_config JSONB DEFAULT '[]'::jsonb;
ALTER TABLE marketplace_agents ADD COLUMN IF NOT EXISTS heartbeat_config JSONB DEFAULT '{}'::jsonb;
ALTER TABLE marketplace_agents ADD COLUMN IF NOT EXISTS channels_config JSONB DEFAULT '{}'::jsonb;
ALTER TABLE marketplace_agents ADD COLUMN IF NOT EXISTS system_prompt TEXT DEFAULT '';
ALTER TABLE marketplace_agents ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE marketplace_agents ADD COLUMN IF NOT EXISTS model TEXT DEFAULT 'openclaw';
ALTER TABLE marketplace_agents ADD COLUMN IF NOT EXISTS creator_id TEXT;
ALTER TABLE marketplace_agents ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT true;
ALTER TABLE marketplace_agents ADD COLUMN IF NOT EXISTS max_runtime_hours INTEGER DEFAULT 0;

-- ============================================================================
-- 2. USER_INSTALLED_AGENTS — which agents a user has installed / activated
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_installed_agents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  agent_id UUID NOT NULL REFERENCES marketplace_agents(id) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  config_overrides JSONB DEFAULT '{}'::jsonb,
  installed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_used_at TIMESTAMPTZ,
  UNIQUE (user_id, agent_id)
);

CREATE INDEX IF NOT EXISTS idx_user_installed_agents_user ON user_installed_agents(user_id) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_user_installed_agents_agent ON user_installed_agents(agent_id);

-- ============================================================================
-- 3. AGENT_TASKS — tasks assigned to agents (can run in background)
-- ============================================================================
CREATE TABLE IF NOT EXISTS agent_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  agent_id UUID NOT NULL REFERENCES marketplace_agents(id) ON DELETE CASCADE,
  conversation_id TEXT,
  -- Task definition
  task_prompt TEXT NOT NULL,
  task_type TEXT NOT NULL DEFAULT 'one-shot',  -- 'one-shot', 'recurring', 'long-running'
  -- Execution state
  status TEXT NOT NULL DEFAULT 'pending',  -- 'pending', 'running', 'completed', 'failed', 'cancelled'
  result TEXT,
  error TEXT,
  progress INTEGER DEFAULT 0,  -- 0-100
  -- Timing
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  scheduled_for TIMESTAMPTZ,
  -- Heartbeat: for recurring/long-running tasks
  heartbeat_interval TEXT,  -- e.g. '30m', '1h', '24h'
  last_heartbeat_at TIMESTAMPTZ,
  next_heartbeat_at TIMESTAMPTZ,
  max_runtime_hours INTEGER DEFAULT 24,
  -- Metadata
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agent_tasks_user ON agent_tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_agent_tasks_agent ON agent_tasks(agent_id);
CREATE INDEX IF NOT EXISTS idx_agent_tasks_status ON agent_tasks(status) WHERE status IN ('pending', 'running');
CREATE INDEX IF NOT EXISTS idx_agent_tasks_next_heartbeat ON agent_tasks(next_heartbeat_at) WHERE status = 'running';

-- ============================================================================
-- 4. AGENT_MEMORY — persistent memory for agents (per user)
-- ============================================================================
CREATE TABLE IF NOT EXISTS agent_memory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id UUID NOT NULL REFERENCES marketplace_agents(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL,
  memory_type TEXT NOT NULL DEFAULT 'conversation',  -- 'conversation', 'long-term', 'preference'
  content TEXT NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agent_memory_agent_user ON agent_memory(agent_id, user_id);
CREATE INDEX IF NOT EXISTS idx_agent_memory_type ON agent_memory(memory_type);
