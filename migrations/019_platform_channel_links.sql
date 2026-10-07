-- Platform channel links: maps external platform identities to mawaDao users.
-- Used by the SaaS channel routing model where mawaDao owns the bots.
-- No bot tokens needed from users — just their platform identity.

CREATE TABLE IF NOT EXISTS platform_channel_links (
  id                UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform          VARCHAR(32) NOT NULL,     -- 'telegram', 'discord', 'whatsapp'
  platform_user_id  VARCHAR(128) NOT NULL,    -- telegram user_id, discord user_id, phone number
  platform_meta     JSONB       DEFAULT '{}', -- username, guild_id, first_name, etc.
  is_active         BOOLEAN     NOT NULL DEFAULT true,
  linked_at         TIMESTAMPTZ DEFAULT NOW(),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(platform, platform_user_id)          -- one platform identity = one mawaDao user
);

CREATE INDEX IF NOT EXISTS idx_platform_channel_links_user_id
  ON platform_channel_links(user_id);
CREATE INDEX IF NOT EXISTS idx_platform_channel_links_platform
  ON platform_channel_links(platform);
CREATE INDEX IF NOT EXISTS idx_platform_channel_links_lookup
  ON platform_channel_links(platform, platform_user_id) WHERE is_active = true;

-- Auto-update updated_at on row change
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_platform_channel_links_updated_at'
  ) THEN
    CREATE TRIGGER trg_platform_channel_links_updated_at
      BEFORE UPDATE ON platform_channel_links
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;
