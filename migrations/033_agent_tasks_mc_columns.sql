-- 033: Add Mission Control sync columns to agent_tasks
-- These columns enable bidirectional task sync between agent_tasks and MC boards.

ALTER TABLE agent_tasks
  ADD COLUMN IF NOT EXISTS mc_task_id TEXT,
  ADD COLUMN IF NOT EXISTS mc_board_id TEXT,
  ADD COLUMN IF NOT EXISTS sync_version INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_agent_tasks_mc_task_id
  ON agent_tasks(mc_task_id) WHERE mc_task_id IS NOT NULL;
