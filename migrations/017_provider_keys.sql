-- Per-user AI provider API keys (OpenAI, Anthropic, Google, OpenRouter, etc.)
-- Credentials are stored encrypted at the application layer.

CREATE TABLE IF NOT EXISTS provider_keys (
  id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider      VARCHAR(50) NOT NULL,   -- 'openai', 'anthropic', 'google', 'openrouter'
  api_key       TEXT        NOT NULL,   -- encrypted at application layer
  label         VARCHAR(255),           -- optional user-friendly label
  is_active     BOOLEAN     NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, provider)
);

CREATE INDEX IF NOT EXISTS idx_provider_keys_user_id  ON provider_keys(user_id);
CREATE INDEX IF NOT EXISTS idx_provider_keys_provider ON provider_keys(provider);
CREATE INDEX IF NOT EXISTS idx_provider_keys_active   ON provider_keys(user_id, is_active) WHERE is_active = true;

-- Auto-update updated_at on row change
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_provider_keys_updated_at'
  ) THEN
    CREATE TRIGGER trg_provider_keys_updated_at
      BEFORE UPDATE ON provider_keys
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;
