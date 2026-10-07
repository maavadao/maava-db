-- Channel connections: stores bot tokens/credentials per user per channel type.
-- NOTE: In production, encrypt credentials at the application layer before INSERT.

CREATE TABLE IF NOT EXISTS agent_channels (
  id                UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  agent_id          UUID        REFERENCES agents(id) ON DELETE SET NULL,
  channel_type      VARCHAR(50) NOT NULL,
  channel_name      VARCHAR(255),
  credentials       JSONB       NOT NULL DEFAULT '{}',
  metadata          JSONB       DEFAULT '{}',
  is_active         BOOLEAN     NOT NULL DEFAULT true,
  connected_at      TIMESTAMPTZ,
  last_error        TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, channel_type)
);

CREATE INDEX IF NOT EXISTS idx_agent_channels_user_id      ON agent_channels(user_id);
CREATE INDEX IF NOT EXISTS idx_agent_channels_channel_type ON agent_channels(channel_type);
CREATE INDEX IF NOT EXISTS idx_agent_channels_is_active    ON agent_channels(is_active) WHERE is_active = true;

-- Auto-update updated_at on row change
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_agent_channels_updated_at'
  ) THEN
    CREATE TRIGGER trg_agent_channels_updated_at
      BEFORE UPDATE ON agent_channels
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;
