-- Migration 015: Row-Level Security (RLS) Policies
-- Enables PostgreSQL RLS on all tenant-scoped tables to enforce data isolation.
--
-- How it works:
-- 1. Application sets the current user via: SET app.current_user_id = 'uuid';
--    (done at connection/transaction start by the application layer)
-- 2. RLS policies automatically filter rows so each user only sees their own data
-- 3. Even if application code has a bug, the database prevents data leakage
--
-- Two policy types:
-- - "tenant_isolation": user can only see/modify rows where user_id matches
-- - "public_read":      anyone can read, but only owner can modify (for communities, marketplace)

BEGIN;

-- ============================================================================
-- 1. ENABLE RLS ON ALL TABLES
-- ============================================================================

ALTER TABLE agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_moderators ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_community_post_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_channels ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 2. AGENTS — Owner can manage their own agents
-- ============================================================================

CREATE POLICY agents_select ON agents
  FOR SELECT USING (
    user_id = current_setting('app.current_user_id', true)::uuid
    OR user_id IS NULL  -- unclaimed agents visible to all
  );

CREATE POLICY agents_insert ON agents
  FOR INSERT WITH CHECK (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY agents_update ON agents
  FOR UPDATE USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY agents_delete ON agents
  FOR DELETE USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

-- ============================================================================
-- 3. POSTS — Public read, owner write
-- ============================================================================

CREATE POLICY posts_select ON posts
  FOR SELECT USING (true);  -- All posts are publicly readable (social platform)

CREATE POLICY posts_insert ON posts
  FOR INSERT WITH CHECK (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY posts_update ON posts
  FOR UPDATE USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY posts_delete ON posts
  FOR DELETE USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

-- ============================================================================
-- 4. COMMENTS — Public read, owner write
-- ============================================================================

CREATE POLICY comments_select ON comments
  FOR SELECT USING (true);

CREATE POLICY comments_insert ON comments
  FOR INSERT WITH CHECK (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY comments_update ON comments
  FOR UPDATE USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY comments_delete ON comments
  FOR DELETE USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

-- ============================================================================
-- 5. VOTES — Owner only
-- ============================================================================

CREATE POLICY votes_select ON votes
  FOR SELECT USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY votes_insert ON votes
  FOR INSERT WITH CHECK (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY votes_delete ON votes
  FOR DELETE USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

-- ============================================================================
-- 6. FOLLOWS — Owner manages their follows, public read for follower counts
-- ============================================================================

CREATE POLICY follows_select ON follows
  FOR SELECT USING (true);  -- Follow relationships are public

CREATE POLICY follows_insert ON follows
  FOR INSERT WITH CHECK (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY follows_delete ON follows
  FOR DELETE USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

-- ============================================================================
-- 7. SUBSCRIPTIONS — Owner only
-- ============================================================================

CREATE POLICY subscriptions_select ON subscriptions
  FOR SELECT USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY subscriptions_insert ON subscriptions
  FOR INSERT WITH CHECK (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY subscriptions_delete ON subscriptions
  FOR DELETE USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

-- ============================================================================
-- 8. COMMUNITIES — Public read, owner/creator write
-- ============================================================================

CREATE POLICY communities_select ON communities
  FOR SELECT USING (true);  -- Communities are public communities

CREATE POLICY communities_insert ON communities
  FOR INSERT WITH CHECK (
    user_id = current_setting('app.current_user_id', true)::uuid
    OR user_id IS NULL  -- system-created communities
  );

CREATE POLICY communities_update ON communities
  FOR UPDATE USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

-- ============================================================================
-- 9. MARKETPLACE — Public read, owner write
-- ============================================================================

CREATE POLICY marketplace_listings_select ON marketplace_listings
  FOR SELECT USING (true);  -- Marketplace is publicly browsable

CREATE POLICY marketplace_listings_insert ON marketplace_listings
  FOR INSERT WITH CHECK (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY marketplace_listings_update ON marketplace_listings
  FOR UPDATE USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY marketplace_orders_select ON marketplace_orders
  FOR SELECT USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY marketplace_orders_insert ON marketplace_orders
  FOR INSERT WITH CHECK (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

-- ============================================================================
-- 10. TENANTS — Owner only
-- ============================================================================

CREATE POLICY tenants_select ON tenants
  FOR SELECT USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY tenants_update ON tenants
  FOR UPDATE USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

-- ============================================================================
-- 11. AGENT CHANNELS — Owner only
-- ============================================================================

CREATE POLICY agent_channels_select ON agent_channels
  FOR SELECT USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY agent_channels_insert ON agent_channels
  FOR INSERT WITH CHECK (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY agent_channels_update ON agent_channels
  FOR UPDATE USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY agent_channels_delete ON agent_channels
  FOR DELETE USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

-- ============================================================================
-- 12. COMMUNITY MODERATORS — Owner only for write
-- ============================================================================

CREATE POLICY community_moderators_select ON community_moderators
  FOR SELECT USING (true);  -- Moderator lists are public

CREATE POLICY community_moderators_insert ON community_moderators
  FOR INSERT WITH CHECK (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY community_moderators_delete ON community_moderators
  FOR DELETE USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

-- ============================================================================
-- 13. AI COMMUNITY POST SNAPSHOTS — Public read, owner write
-- ============================================================================

CREATE POLICY ai_snapshots_select ON ai_community_post_snapshots
  FOR SELECT USING (true);

CREATE POLICY ai_snapshots_insert ON ai_community_post_snapshots
  FOR INSERT WITH CHECK (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

CREATE POLICY ai_snapshots_update ON ai_community_post_snapshots
  FOR UPDATE USING (
    user_id = current_setting('app.current_user_id', true)::uuid
  );

-- ============================================================================
-- 14. HELPER FUNCTION — Set current user for RLS
-- ============================================================================
-- Application code calls this at the start of each request/transaction:
--   SELECT set_current_user_id('uuid-here');

CREATE OR REPLACE FUNCTION set_current_user_id(uid TEXT)
RETURNS VOID AS $$
BEGIN
  PERFORM set_config('app.current_user_id', uid, true);  -- true = local to transaction
END;
$$ LANGUAGE plpgsql;

COMMIT;
