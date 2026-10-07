-- 024: Wallet Tables — PaySponge wallet settings, balance caching,
--      pending actions with approval gates, and audit logging.
--
-- Tables: wallet_settings, wallet_balance_cache, wallet_pending_actions,
--         wallet_audit_logs
-- Supports: seller wallet configuration, cached balances for fast reads,
--           approval-gated financial actions, and compliance-grade audit trail.

-- ═══════════════════════════════════════════════════════════════════════════
-- wallet_settings — per-seller wallet configuration and encrypted key ref
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS wallet_settings (
  id                UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  seller_profile_id UUID         NOT NULL REFERENCES seller_profiles(id) ON DELETE CASCADE,

  -- Sponge connection
  sponge_wallet_id  TEXT,                                                    -- PaySponge wallet identifier
  sponge_key_ref    TEXT,                                                    -- encrypted key reference (never store raw key)
  is_connected      BOOLEAN      NOT NULL DEFAULT false,

  -- Policy
  daily_limit       NUMERIC(12,2) DEFAULT 1000.00,                           -- max daily spend in USDC
  require_approval  BOOLEAN       NOT NULL DEFAULT true,                     -- require human approval for actions
  auto_approve_max  NUMERIC(12,2) DEFAULT 10.00,                             -- auto-approve actions below this amount
  allowed_chains    TEXT[]        DEFAULT ARRAY['base', 'solana'],            -- whitelisted chains

  metadata          JSONB         DEFAULT '{}',
  created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

  CONSTRAINT ws_one_per_user UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS idx_ws_user_id           ON wallet_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_ws_seller_profile_id ON wallet_settings(seller_profile_id);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_ws_updated_at') THEN
    CREATE TRIGGER trg_ws_updated_at
      BEFORE UPDATE ON wallet_settings
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- wallet_balance_cache — cached balances for fast UI reads (60s TTL)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS wallet_balance_cache (
  id                UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  chain             TEXT         NOT NULL,
  token             TEXT         NOT NULL DEFAULT 'USDC',
  balance           NUMERIC(18,8) NOT NULL DEFAULT 0,
  raw_response      JSONB,                                                   -- full Sponge API response
  fetched_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

  CONSTRAINT wbc_unique_chain_token UNIQUE (user_id, chain, token)
);

CREATE INDEX IF NOT EXISTS idx_wbc_user_id    ON wallet_balance_cache(user_id);
CREATE INDEX IF NOT EXISTS idx_wbc_fetched_at ON wallet_balance_cache(fetched_at);

-- ═══════════════════════════════════════════════════════════════════════════
-- wallet_pending_actions — approval-gated financial operations
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS wallet_pending_actions (
  id                UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Action details
  action_type       TEXT         NOT NULL
                                 CHECK (action_type IN (
                                   'transfer', 'swap', 'bridge', 'payment_link',
                                   'x402_payment', 'trading_buy', 'trading_sell'
                                 )),
  amount            NUMERIC(18,8),
  currency          TEXT         DEFAULT 'USDC',
  chain             TEXT,
  destination       TEXT,                                                    -- wallet address or payment target
  params            JSONB        NOT NULL DEFAULT '{}',                       -- full action parameters

  -- Approval
  status            TEXT         NOT NULL DEFAULT 'pending'
                                 CHECK (status IN ('pending', 'approved', 'rejected', 'executed', 'failed', 'expired')),
  requested_by      TEXT         NOT NULL DEFAULT 'agent',                    -- 'agent' or 'user'
  approved_by       TEXT,                                                     -- 'user' or 'auto'
  rejection_reason  TEXT,

  -- Execution
  executed_at       TIMESTAMPTZ,
  result            JSONB,                                                   -- Sponge API response after execution
  error             TEXT,

  -- Lifecycle
  expires_at        TIMESTAMPTZ  DEFAULT (NOW() + INTERVAL '24 hours'),
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wpa_user_id     ON wallet_pending_actions(user_id);
CREATE INDEX IF NOT EXISTS idx_wpa_status      ON wallet_pending_actions(status);
CREATE INDEX IF NOT EXISTS idx_wpa_action_type ON wallet_pending_actions(action_type);
CREATE INDEX IF NOT EXISTS idx_wpa_expires_at  ON wallet_pending_actions(expires_at);
CREATE INDEX IF NOT EXISTS idx_wpa_created_at  ON wallet_pending_actions(created_at DESC);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_wpa_updated_at') THEN
    CREATE TRIGGER trg_wpa_updated_at
      BEFORE UPDATE ON wallet_pending_actions
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- wallet_audit_logs — immutable audit trail for all wallet operations
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS wallet_audit_logs (
  id                UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  event_type        TEXT         NOT NULL,                                    -- 'balance_check', 'transfer', 'swap', 'approval', etc.
  action_id         UUID         REFERENCES wallet_pending_actions(id),       -- link to action if applicable
  order_id          UUID,                                                     -- link to order if applicable (FK added later if product_orders exists)

  amount            NUMERIC(18,8),
  currency          TEXT,
  chain             TEXT,
  status            TEXT,                                                     -- 'success', 'failed', 'rejected'
  actor             TEXT         NOT NULL DEFAULT 'agent',                    -- 'agent', 'user', 'webhook', 'system'
  details           JSONB        DEFAULT '{}',                                -- context-specific data
  ip_address        TEXT,

  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wal_user_id     ON wallet_audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_wal_event_type  ON wallet_audit_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_wal_action_id   ON wallet_audit_logs(action_id);
CREATE INDEX IF NOT EXISTS idx_wal_created_at  ON wallet_audit_logs(created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════
-- RLS — wallet_settings
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE wallet_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY ws_owner_policy ON wallet_settings
  FOR ALL
  USING (user_id::text = current_setting('app.current_user_id', true))
  WITH CHECK (user_id::text = current_setting('app.current_user_id', true));

ALTER TABLE wallet_settings FORCE ROW LEVEL SECURITY;

-- ═══════════════════════════════════════════════════════════════════════════
-- RLS — wallet_balance_cache
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE wallet_balance_cache ENABLE ROW LEVEL SECURITY;

CREATE POLICY wbc_owner_policy ON wallet_balance_cache
  FOR ALL
  USING (user_id::text = current_setting('app.current_user_id', true))
  WITH CHECK (user_id::text = current_setting('app.current_user_id', true));

ALTER TABLE wallet_balance_cache FORCE ROW LEVEL SECURITY;

-- ═══════════════════════════════════════════════════════════════════════════
-- RLS — wallet_pending_actions
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE wallet_pending_actions ENABLE ROW LEVEL SECURITY;

CREATE POLICY wpa_owner_policy ON wallet_pending_actions
  FOR ALL
  USING (user_id::text = current_setting('app.current_user_id', true))
  WITH CHECK (user_id::text = current_setting('app.current_user_id', true));

CREATE POLICY wpa_service_policy ON wallet_pending_actions
  FOR ALL
  USING (current_setting('app.service_role', true) = 'webhook')
  WITH CHECK (current_setting('app.service_role', true) = 'webhook');

ALTER TABLE wallet_pending_actions FORCE ROW LEVEL SECURITY;

-- ═══════════════════════════════════════════════════════════════════════════
-- RLS — wallet_audit_logs
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE wallet_audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY wal_owner_select ON wallet_audit_logs
  FOR SELECT
  USING (user_id::text = current_setting('app.current_user_id', true));

CREATE POLICY wal_owner_insert ON wallet_audit_logs
  FOR INSERT
  WITH CHECK (user_id::text = current_setting('app.current_user_id', true));

CREATE POLICY wal_service_policy ON wallet_audit_logs
  FOR ALL
  USING (current_setting('app.service_role', true) = 'webhook')
  WITH CHECK (current_setting('app.service_role', true) = 'webhook');

ALTER TABLE wallet_audit_logs FORCE ROW LEVEL SECURITY;

-- ═══════════════════════════════════════════════════════════════════════════
-- Optional FK Constraint — add only if product_orders exists
-- ═══════════════════════════════════════════════════════════════════════════

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'product_orders') THEN
    ALTER TABLE wallet_audit_logs
      ADD CONSTRAINT fk_wallet_audit_logs_order_id
      FOREIGN KEY (order_id) REFERENCES product_orders(id) ON DELETE SET NULL;
  END IF;
END $$;
