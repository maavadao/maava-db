-- Add gateway_token column to tenants table.
-- Stores the per-tenant OPENCLAW_GATEWAY_TOKEN used for authenticating
-- chat proxy requests from the dashboard to the tenant's Cloud Run backend.

ALTER TABLE tenants ADD COLUMN IF NOT EXISTS gateway_token TEXT;
