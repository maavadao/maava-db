-- 035: Scheduled deliveries (campaign cron jobs)
-- Backs the [SCHEDULE_DELIVERY] action block. Rows are materialized by
-- ActionExecutorService and dispatched once-per-minute by the in-process
-- ScheduledDeliveryWorker living in the configuration-api.

CREATE TABLE IF NOT EXISTS scheduled_deliveries (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  agent_task_id     UUID REFERENCES agent_tasks(id) ON DELETE SET NULL,
  conversation_id   UUID REFERENCES conversations(id) ON DELETE SET NULL,
  name              TEXT NOT NULL,
  message_template  TEXT NOT NULL,
  cron_expression   TEXT NOT NULL,             -- 5-field crontab
  platforms         JSONB NOT NULL DEFAULT '["all"]'::jsonb,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  last_run_at       TIMESTAMPTZ,
  next_run_at       TIMESTAMPTZ,
  run_count         INT NOT NULL DEFAULT 0,
  fail_count        INT NOT NULL DEFAULT 0,
  last_error        TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sched_due  ON scheduled_deliveries(next_run_at)
  WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_sched_user ON scheduled_deliveries(user_id);

ALTER TABLE scheduled_deliveries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS scheduled_deliveries_user_policy ON scheduled_deliveries;
CREATE POLICY scheduled_deliveries_user_policy ON scheduled_deliveries
  USING (user_id = current_setting('app.user_id', true)::uuid);
