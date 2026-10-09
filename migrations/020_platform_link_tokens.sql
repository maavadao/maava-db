-- Temporary link tokens for the deep-link flow.
-- User generates a token on the dashboard, opens t.me/maavadao_bot?start=TOKEN,
-- bot validates the token and creates the real platform_channel_links entry.

CREATE TABLE IF NOT EXISTS platform_link_tokens (
  token      VARCHAR(64) PRIMARY KEY,
  user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform   VARCHAR(32) NOT NULL,   -- 'telegram', 'discord', 'whatsapp'
  expires_at TIMESTAMPTZ NOT NULL,
  used_at    TIMESTAMPTZ DEFAULT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_link_tokens_user_platform
  ON platform_link_tokens(user_id, platform);
CREATE INDEX IF NOT EXISTS idx_link_tokens_lookup
  ON platform_link_tokens(token) WHERE used_at IS NULL;
