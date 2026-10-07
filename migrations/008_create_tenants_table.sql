-- Tenants: maps each user to their subdomain and per-user Cloud Run backend.
-- 1:1 relationship — each user gets exactly one tenant/subdomain.

CREATE TABLE IF NOT EXISTS tenants (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  agent_id    UUID REFERENCES agents(id) ON DELETE SET NULL,
  subdomain   VARCHAR(63) NOT NULL UNIQUE,
  backend_url TEXT,
  cloud_run_service_name VARCHAR(255),
  storage_bucket TEXT,
  region      VARCHAR(50) NOT NULL DEFAULT 'europe-west1',
  status      VARCHAR(20) NOT NULL DEFAULT 'provisioning'
              CHECK (status IN ('provisioning', 'active', 'suspended', 'deleted')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Fast lookup by subdomain (primary routing path)
CREATE INDEX IF NOT EXISTS idx_tenants_subdomain ON tenants(subdomain) WHERE status = 'active';

-- Fast lookup by agent
CREATE INDEX IF NOT EXISTS idx_tenants_agent ON tenants(agent_id) WHERE agent_id IS NOT NULL;

-- Active tenant count
CREATE INDEX IF NOT EXISTS idx_tenants_status ON tenants(status);
