-- Slack OAuth workspace installations
-- Each row = one mawaDao user installing the shared mawaDao Slack app into one workspace

CREATE TABLE IF NOT EXISTS slack_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mawadao_user_id TEXT NOT NULL,
  slack_team_id VARCHAR(64) NOT NULL,
  slack_team_name VARCHAR(255),
  slack_bot_token TEXT NOT NULL,
  slack_bot_user_id VARCHAR(64),
  slack_authed_user_id VARCHAR(64),
  slack_scope TEXT,
  slack_enterprise_id VARCHAR(64),
  slack_installed_by_user_id VARCHAR(64),
  slack_app_id VARCHAR(64),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (slack_team_id, mawadao_user_id)
);

CREATE INDEX IF NOT EXISTS idx_slack_connections_mawadao_user_id
  ON slack_connections(mawadao_user_id) WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_slack_connections_slack_team_id
  ON slack_connections(slack_team_id) WHERE is_active = true;

-- Optional: bind individual Slack users to mawaDao users
-- Used when multiple users in one Slack workspace map to different mawaDao tenants
CREATE TABLE IF NOT EXISTS slack_identity_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mawadao_user_id TEXT NOT NULL,
  slack_team_id VARCHAR(64) NOT NULL,
  slack_user_id VARCHAR(64) NOT NULL,
  slack_channel_id VARCHAR(64),
  linked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (slack_team_id, slack_user_id)
);

CREATE INDEX IF NOT EXISTS idx_slack_identity_links_team
  ON slack_identity_links(slack_team_id);

-- Event deduplication table (TTL-based cleanup recommended)
CREATE TABLE IF NOT EXISTS slack_event_log (
  event_id VARCHAR(64) PRIMARY KEY,
  team_id VARCHAR(64) NOT NULL,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_slack_event_log_processed
  ON slack_event_log(processed_at);
