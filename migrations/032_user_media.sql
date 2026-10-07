-- ═══════════════════════════════════════════════════════════════════════════
-- user_media — stores ALL AI-generated / uploaded images per user.
-- Images land here first; when a product is created from them, a row is also
-- inserted into product_assets referencing the same file_url.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS user_media (
  id              UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  file_url        TEXT         NOT NULL,
  file_name       TEXT,
  mime_type       TEXT,
  source          TEXT         NOT NULL DEFAULT 'ai_generated'
                               CHECK (source IN ('ai_generated', 'uploaded', 'external')),
  generation_prompt TEXT,
  metadata        JSONB        DEFAULT '{}',
  product_id      UUID         REFERENCES products(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_media_user_id   ON user_media(user_id);
CREATE INDEX IF NOT EXISTS idx_user_media_product   ON user_media(product_id) WHERE product_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_media_created    ON user_media(user_id, created_at DESC);

-- Unique constraint on user_media to prevent duplicate file_url per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_media_unique_url ON user_media(user_id, file_url);

-- Unique constraint on product_assets to prevent duplicate file_url per product
CREATE UNIQUE INDEX IF NOT EXISTS idx_product_assets_unique_url ON product_assets(product_id, file_url);

-- RLS
ALTER TABLE user_media ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'user_media_tenant_isolation') THEN
    CREATE POLICY user_media_tenant_isolation ON user_media
      USING (user_id = current_setting('app.current_user_id', true)::uuid);
  END IF;
END $$;
