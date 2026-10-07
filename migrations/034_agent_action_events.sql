-- 034: Per-action live progress events
-- One row per ACTION block executed (CREATE_PRODUCT, PUBLISH_PRODUCT,
-- SCHEDULE_DELIVERY, etc.). Used to drive the chat sidebar "Live actions"
-- feed and to push short comments to the linked Mission Control task.

CREATE TABLE IF NOT EXISTS agent_action_events (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  agent_task_id   UUID REFERENCES agent_tasks(id) ON DELETE SET NULL,
  kind            TEXT NOT NULL,                -- e.g. CREATE_PRODUCT, PUBLISH_PRODUCT
  status          TEXT NOT NULL DEFAULT 'success', -- success | error | skipped
  message         TEXT NOT NULL,                -- short user-facing line (<= 200 chars)
  metadata        JSONB DEFAULT '{}'::jsonb,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_aae_conv     ON agent_action_events(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_aae_task     ON agent_action_events(agent_task_id,   created_at DESC);
CREATE INDEX IF NOT EXISTS idx_aae_user     ON agent_action_events(user_id,         created_at DESC);

ALTER TABLE agent_action_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS aae_user_policy ON agent_action_events;
CREATE POLICY aae_user_policy ON agent_action_events
  USING (user_id = current_setting('app.user_id', true)::uuid);
