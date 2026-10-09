-- 021: Dedicated Telegram tables for production-grade integration.
-- telegram_channel_links — Telegram-specific account links with richer metadata.
-- telegram_message_logs — Full audit trail for inbound + outbound messages.

-- ═══════════════════════════════════════════════════════════════════════════
-- telegram_channel_links
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS telegram_channel_links (
  id                  UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  maavadao_user_id      UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  telegram_user_id    BIGINT       NOT NULL,
  telegram_chat_id    BIGINT,
  telegram_username   TEXT,
  telegram_first_name TEXT,
  telegram_last_name  TEXT,
  linked_via          TEXT         CHECK (linked_via IN ('widget', 'deep_link', 'manual')),
  bot_scoped          BOOLEAN      DEFAULT true,
  is_active           BOOLEAN      DEFAULT true,
  last_seen_at        TIMESTAMPTZ,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE(telegram_user_id)
);

CREATE INDEX IF NOT EXISTS idx_tcl_maavadao_user_id
  ON telegram_channel_links(maavadao_user_id);
CREATE INDEX IF NOT EXISTS idx_tcl_telegram_user_id
  ON telegram_channel_links(telegram_user_id) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_tcl_telegram_chat_id
  ON telegram_channel_links(telegram_chat_id) WHERE telegram_chat_id IS NOT NULL;

-- Auto-update updated_at
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_tcl_updated_at'
  ) THEN
    CREATE TRIGGER trg_tcl_updated_at
      BEFORE UPDATE ON telegram_channel_links
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- telegram_message_logs — audit trail for every inbound & outbound message
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS telegram_message_logs (
  id                  UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  telegram_update_id  BIGINT       UNIQUE,
  maavadao_user_id      UUID,
  telegram_user_id    BIGINT,
  telegram_chat_id    BIGINT,
  direction           TEXT         NOT NULL CHECK (direction IN ('inbound', 'outbound')),
  message_text        TEXT,
  telegram_message_id BIGINT,
  status              TEXT         DEFAULT 'pending',  -- pending, sent, delivered, failed, duplicate
  error               TEXT,
  metadata            JSONB        DEFAULT '{}',
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tml_telegram_update_id
  ON telegram_message_logs(telegram_update_id) WHERE telegram_update_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tml_maavadao_user_id
  ON telegram_message_logs(maavadao_user_id) WHERE maavadao_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tml_telegram_user_id
  ON telegram_message_logs(telegram_user_id);
CREATE INDEX IF NOT EXISTS idx_tml_telegram_chat_id
  ON telegram_message_logs(telegram_chat_id);
CREATE INDEX IF NOT EXISTS idx_tml_created_at
  ON telegram_message_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tml_direction_status
  ON telegram_message_logs(direction, status);

-- ═══════════════════════════════════════════════════════════════════════════
-- Migrate existing Telegram links from platform_channel_links (if any)
-- ═══════════════════════════════════════════════════════════════════════════

INSERT INTO telegram_channel_links (
  maavadao_user_id,
  telegram_user_id,
  telegram_chat_id,
  telegram_username,
  telegram_first_name,
  telegram_last_name,
  linked_via,
  is_active,
  created_at,
  updated_at
)
SELECT
  pcl.user_id,
  pcl.platform_user_id::BIGINT,
  pcl.platform_user_id::BIGINT,          -- chat_id same as user_id for DMs
  pcl.platform_meta->>'username',
  pcl.platform_meta->>'firstName',
  pcl.platform_meta->>'lastName',
  'deep_link',                            -- all existing links were via deep-link
  pcl.is_active,
  pcl.created_at,
  COALESCE(pcl.updated_at, pcl.created_at)
FROM platform_channel_links pcl
WHERE pcl.platform = 'telegram'
  AND pcl.platform_user_id ~ '^\d+$'     -- safety: only numeric IDs
ON CONFLICT (telegram_user_id) DO NOTHING;
