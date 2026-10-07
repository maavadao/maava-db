-- Seed existing users into tenants table.
-- Uses username as subdomain, status 'active', skips users who already have a tenant row.

INSERT INTO tenants (id, user_id, subdomain, region, status, created_at, updated_at)
SELECT
  uuid_generate_v4(),
  u.id,
  LOWER(u.username),
  'europe-west1',
  'active',
  NOW(),
  NOW()
FROM users u
WHERE NOT EXISTS (
  SELECT 1 FROM tenants t WHERE t.user_id = u.id
);
