-- 037_inbox_accounts.sql
-- Inbox feature: Gmail / Outlook OAuth account links + per-account AI policy.
-- Tokens are stored ENCRYPTED (AES-256-GCM via INBOX_TOKEN_ENCRYPTION_KEY).
-- This migration is idempotent.

CREATE TABLE IF NOT EXISTS inbox_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  provider TEXT NOT NULL CHECK (provider IN ('gmail', 'outlook')),
  account_email TEXT NOT NULL,
  display_name TEXT,
  scopes TEXT[] NOT NULL DEFAULT '{}',
  token_ciphertext TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked', 'error')),
  last_error TEXT,
  last_synced_at TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, provider, account_email)
);

CREATE INDEX IF NOT EXISTS idx_inbox_accounts_user
  ON inbox_accounts(user_id) WHERE status = 'active';

CREATE TABLE IF NOT EXISTS inbox_ai_policies (
  account_id UUID PRIMARY KEY REFERENCES inbox_accounts(id) ON DELETE CASCADE,
  mode TEXT NOT NULL DEFAULT 'approval_required'
    CHECK (mode IN ('off', 'approval_required', 'autonomous')),
  can_send BOOLEAN NOT NULL DEFAULT FALSE,
  can_reply BOOLEAN NOT NULL DEFAULT FALSE,
  can_forward BOOLEAN NOT NULL DEFAULT FALSE,
  can_delete BOOLEAN NOT NULL DEFAULT FALSE,
  can_archive BOOLEAN NOT NULL DEFAULT FALSE,
  can_label BOOLEAN NOT NULL DEFAULT FALSE,
  approval_required_for_send BOOLEAN NOT NULL DEFAULT TRUE,
  max_actions_per_hour INTEGER NOT NULL DEFAULT 20,
  excluded_addresses TEXT[] NOT NULL DEFAULT '{}',
  excluded_labels TEXT[] NOT NULL DEFAULT '{}',
  allowed_label_targets TEXT[] NOT NULL DEFAULT '{}',
  custom_instructions TEXT NOT NULL DEFAULT '',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS inbox_oauth_states (
  state_token TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  provider TEXT NOT NULL CHECK (provider IN ('gmail', 'outlook')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  consumed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_inbox_oauth_states_created
  ON inbox_oauth_states(created_at);
