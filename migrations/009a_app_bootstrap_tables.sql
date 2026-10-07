-- Tables the web apps used to create on first request (apps/*/src/lib/db.ts and api/setup).
-- Defined here so a fresh database can be built from migrations alone; the apps' IF NOT EXISTS bootstrap stays compatible.

CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT 'New Chat',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ DEFAULT NULL
  );

CREATE INDEX IF NOT EXISTS idx_conversations_user ON conversations(user_id) WHERE deleted_at IS NULL;

ALTER TABLE conversations ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

ALTER TABLE conversations ADD COLUMN IF NOT EXISTS is_streaming BOOLEAN DEFAULT FALSE;

ALTER TABLE conversations ADD COLUMN IF NOT EXISTS streaming_started_at TIMESTAMPTZ DEFAULT NULL;

CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ DEFAULT NULL
  );

CREATE INDEX IF NOT EXISTS idx_messages_conv ON messages(conversation_id, created_at) WHERE deleted_at IS NULL;

ALTER TABLE messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

ALTER TABLE IF EXISTS conversations ADD COLUMN IF NOT EXISTS agent_id TEXT DEFAULT NULL;

ALTER TABLE IF EXISTS messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

CREATE INDEX IF NOT EXISTS idx_conversations_user_updated ON conversations(user_id, updated_at DESC) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_messages_conv_created_live ON messages(conversation_id, created_at ASC) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_messages_conv_created ON messages(conversation_id, created_at ASC);

CREATE TABLE IF NOT EXISTS user_skills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  skill_id TEXT NOT NULL,
  source TEXT NOT NULL DEFAULT '',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  installed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, skill_id)
  );

CREATE INDEX IF NOT EXISTS idx_user_skills_user ON user_skills(user_id) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_user_skills_lookup ON user_skills(user_id, skill_id, source);

CREATE TABLE IF NOT EXISTS user_chat_preferences (
  user_id TEXT PRIMARY KEY,
  selected_model TEXT NOT NULL DEFAULT 'openclaw',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );

CREATE TABLE IF NOT EXISTS skills (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  skill_id    TEXT NOT NULL,
  name        TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  category    TEXT NOT NULL DEFAULT 'general',
  installs    INTEGER NOT NULL DEFAULT 0,
  source      TEXT NOT NULL DEFAULT '',
  source_url  TEXT NOT NULL DEFAULT '',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (skill_id, source)
  );

CREATE INDEX IF NOT EXISTS idx_skills_category ON skills(category);

CREATE INDEX IF NOT EXISTS idx_skills_installs ON skills(installs DESC);

CREATE INDEX IF NOT EXISTS idx_skills_category_installs ON skills(category, installs DESC);

CREATE TABLE IF NOT EXISTS marketplace_agents (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug              TEXT UNIQUE NOT NULL,
  name              TEXT NOT NULL,
  description       TEXT NOT NULL DEFAULT '',
  short_description TEXT NOT NULL DEFAULT '',
  category          TEXT NOT NULL DEFAULT 'general',
  developer         TEXT NOT NULL DEFAULT '',
  price             NUMERIC(10,2) NOT NULL DEFAULT 0,
  price_label       TEXT NOT NULL DEFAULT 'Free',
  rating            NUMERIC(3,2) NOT NULL DEFAULT 0,
  review_count      INTEGER NOT NULL DEFAULT 0,
  total_installs    INTEGER NOT NULL DEFAULT 0,
  version           TEXT NOT NULL DEFAULT '1.0.0',
  verified          BOOLEAN NOT NULL DEFAULT FALSE,
  tags              TEXT[] NOT NULL DEFAULT '{}',
  integrations      TEXT[] NOT NULL DEFAULT '{}',
  capabilities      TEXT[] NOT NULL DEFAULT '{}',
  key_benefits      JSONB NOT NULL DEFAULT '[]',
  about             TEXT NOT NULL DEFAULT '',
  icon_url          TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
  );

CREATE INDEX IF NOT EXISTS idx_marketplace_agents_category ON marketplace_agents(category);

CREATE INDEX IF NOT EXISTS idx_marketplace_agents_rating ON marketplace_agents(rating DESC);

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

CREATE TABLE IF NOT EXISTS user_onboarding_preferences (
  user_id TEXT PRIMARY KEY,
  interests TEXT[] NOT NULL DEFAULT '{}',
  provider TEXT NOT NULL DEFAULT 'moonshot',
  onboarding_completed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );

CREATE TABLE IF NOT EXISTS user_skill_api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  skill_key TEXT NOT NULL,
  env_key TEXT NOT NULL,
  key_value TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, skill_key, env_key)
  );

CREATE INDEX IF NOT EXISTS idx_user_skill_api_keys_user ON user_skill_api_keys(user_id);
