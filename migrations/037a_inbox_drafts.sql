-- inbox_drafts was created by the dashboard on first request (src/lib/db.ts); it depends on 037_inbox_accounts.

CREATE TABLE IF NOT EXISTS inbox_drafts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  account_id UUID NOT NULL REFERENCES inbox_accounts(id) ON DELETE CASCADE,
  source_message_id TEXT NOT NULL,
  source_thread_id TEXT,
  to_addr TEXT NOT NULL,
  subject TEXT NOT NULL,
  body_text TEXT NOT NULL,
  model TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'rejected')),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sent_at TIMESTAMPTZ
  );

CREATE INDEX IF NOT EXISTS idx_inbox_drafts_user_status ON inbox_drafts(user_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_inbox_drafts_account ON inbox_drafts(account_id);
