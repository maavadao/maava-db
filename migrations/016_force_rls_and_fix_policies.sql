-- Migration 016: Force RLS & Fix Policies
-- 
-- Fixes two critical issues with migration 015:
-- 1. ENABLE ROW LEVEL SECURITY alone doesn't apply to the table owner (postgres).
--    We need ALTER TABLE ... FORCE ROW LEVEL SECURITY for it to actually apply.
-- 2. current_setting('app.current_user_id', true) returns '' (empty string)
--    when not set. ''::uuid throws a cast error. Using NULLIF to convert '' → NULL.
-- 3. Some INSERT policies need to allow NULL user_id for:
--    - Agent registration (no auth context, agent starts unclaimed)
--    - System-created records

BEGIN;

-- ============================================================================
-- Helper: safe UUID cast that returns NULL for empty/unset config
-- ============================================================================
CREATE OR REPLACE FUNCTION current_user_id() RETURNS uuid AS $$
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::uuid;
$$ LANGUAGE sql STABLE;

-- ============================================================================
-- 1. FORCE RLS ON ALL TABLES
-- ============================================================================
ALTER TABLE agents FORCE ROW LEVEL SECURITY;
ALTER TABLE posts FORCE ROW LEVEL SECURITY;
ALTER TABLE comments FORCE ROW LEVEL SECURITY;
ALTER TABLE votes FORCE ROW LEVEL SECURITY;
ALTER TABLE follows FORCE ROW LEVEL SECURITY;
ALTER TABLE subscriptions FORCE ROW LEVEL SECURITY;
ALTER TABLE marketplace_listings FORCE ROW LEVEL SECURITY;
ALTER TABLE marketplace_orders FORCE ROW LEVEL SECURITY;
ALTER TABLE submolts FORCE ROW LEVEL SECURITY;
ALTER TABLE submolt_moderators FORCE ROW LEVEL SECURITY;
ALTER TABLE ai_community_post_snapshots FORCE ROW LEVEL SECURITY;
ALTER TABLE tenants FORCE ROW LEVEL SECURITY;
ALTER TABLE agent_channels FORCE ROW LEVEL SECURITY;

-- ============================================================================
-- 2. DROP & RECREATE ALL POLICIES (using current_user_id() helper)
-- ============================================================================

-- === AGENTS ===
DROP POLICY IF EXISTS agents_select ON agents;
DROP POLICY IF EXISTS agents_insert ON agents;
DROP POLICY IF EXISTS agents_update ON agents;
DROP POLICY IF EXISTS agents_delete ON agents;

CREATE POLICY agents_select ON agents
  FOR SELECT USING (
    user_id = current_user_id()
    OR user_id IS NULL  -- unclaimed agents visible to all
    OR current_user_id() IS NULL  -- unauthenticated users can browse
  );

CREATE POLICY agents_insert ON agents
  FOR INSERT WITH CHECK (
    user_id = current_user_id()
    OR user_id IS NULL  -- agent registration (no auth → user_id = NULL)
  );

CREATE POLICY agents_update ON agents
  FOR UPDATE USING (
    user_id = current_user_id()
  );

CREATE POLICY agents_delete ON agents
  FOR DELETE USING (
    user_id = current_user_id()
  );

-- === POSTS ===
DROP POLICY IF EXISTS posts_select ON posts;
DROP POLICY IF EXISTS posts_insert ON posts;
DROP POLICY IF EXISTS posts_update ON posts;
DROP POLICY IF EXISTS posts_delete ON posts;

CREATE POLICY posts_select ON posts
  FOR SELECT USING (true);

CREATE POLICY posts_insert ON posts
  FOR INSERT WITH CHECK (
    user_id = current_user_id()
  );

CREATE POLICY posts_update ON posts
  FOR UPDATE USING (
    user_id = current_user_id()
  );

CREATE POLICY posts_delete ON posts
  FOR DELETE USING (
    user_id = current_user_id()
  );

-- === COMMENTS ===
DROP POLICY IF EXISTS comments_select ON comments;
DROP POLICY IF EXISTS comments_insert ON comments;
DROP POLICY IF EXISTS comments_update ON comments;
DROP POLICY IF EXISTS comments_delete ON comments;

CREATE POLICY comments_select ON comments
  FOR SELECT USING (true);

CREATE POLICY comments_insert ON comments
  FOR INSERT WITH CHECK (
    user_id = current_user_id()
  );

CREATE POLICY comments_update ON comments
  FOR UPDATE USING (
    user_id = current_user_id()
  );

CREATE POLICY comments_delete ON comments
  FOR DELETE USING (
    user_id = current_user_id()
  );

-- === VOTES ===
DROP POLICY IF EXISTS votes_select ON votes;
DROP POLICY IF EXISTS votes_insert ON votes;
DROP POLICY IF EXISTS votes_delete ON votes;

-- Votes need public read for aggregation (vote counts on posts/comments)
CREATE POLICY votes_select ON votes
  FOR SELECT USING (true);

CREATE POLICY votes_insert ON votes
  FOR INSERT WITH CHECK (
    user_id = current_user_id()
  );

CREATE POLICY votes_delete ON votes
  FOR DELETE USING (
    user_id = current_user_id()
  );

-- === FOLLOWS ===
DROP POLICY IF EXISTS follows_select ON follows;
DROP POLICY IF EXISTS follows_insert ON follows;
DROP POLICY IF EXISTS follows_delete ON follows;

CREATE POLICY follows_select ON follows
  FOR SELECT USING (true);

CREATE POLICY follows_insert ON follows
  FOR INSERT WITH CHECK (
    user_id = current_user_id()
  );

CREATE POLICY follows_delete ON follows
  FOR DELETE USING (
    user_id = current_user_id()
  );

-- === SUBSCRIPTIONS ===
DROP POLICY IF EXISTS subscriptions_select ON subscriptions;
DROP POLICY IF EXISTS subscriptions_insert ON subscriptions;
DROP POLICY IF EXISTS subscriptions_delete ON subscriptions;

CREATE POLICY subscriptions_select ON subscriptions
  FOR SELECT USING (
    user_id = current_user_id()
  );

CREATE POLICY subscriptions_insert ON subscriptions
  FOR INSERT WITH CHECK (
    user_id = current_user_id()
  );

CREATE POLICY subscriptions_delete ON subscriptions
  FOR DELETE USING (
    user_id = current_user_id()
  );

-- === SUBMOLTS ===
DROP POLICY IF EXISTS submolts_select ON submolts;
DROP POLICY IF EXISTS submolts_insert ON submolts;
DROP POLICY IF EXISTS submolts_update ON submolts;

CREATE POLICY submolts_select ON submolts
  FOR SELECT USING (true);

CREATE POLICY submolts_insert ON submolts
  FOR INSERT WITH CHECK (
    user_id = current_user_id()
    OR user_id IS NULL  -- system-created submolts
  );

CREATE POLICY submolts_update ON submolts
  FOR UPDATE USING (
    user_id = current_user_id()
  );

-- === MARKETPLACE LISTINGS ===
DROP POLICY IF EXISTS marketplace_listings_select ON marketplace_listings;
DROP POLICY IF EXISTS marketplace_listings_insert ON marketplace_listings;
DROP POLICY IF EXISTS marketplace_listings_update ON marketplace_listings;

CREATE POLICY marketplace_listings_select ON marketplace_listings
  FOR SELECT USING (true);

CREATE POLICY marketplace_listings_insert ON marketplace_listings
  FOR INSERT WITH CHECK (
    user_id = current_user_id()
  );

CREATE POLICY marketplace_listings_update ON marketplace_listings
  FOR UPDATE USING (
    user_id = current_user_id()
  );

-- === MARKETPLACE ORDERS ===
DROP POLICY IF EXISTS marketplace_orders_select ON marketplace_orders;
DROP POLICY IF EXISTS marketplace_orders_insert ON marketplace_orders;

CREATE POLICY marketplace_orders_select ON marketplace_orders
  FOR SELECT USING (
    user_id = current_user_id()
  );

CREATE POLICY marketplace_orders_insert ON marketplace_orders
  FOR INSERT WITH CHECK (
    user_id = current_user_id()
  );

-- === TENANTS ===
DROP POLICY IF EXISTS tenants_select ON tenants;
DROP POLICY IF EXISTS tenants_update ON tenants;

CREATE POLICY tenants_select ON tenants
  FOR SELECT USING (
    user_id = current_user_id()
  );

CREATE POLICY tenants_update ON tenants
  FOR UPDATE USING (
    user_id = current_user_id()
  );

-- === AGENT CHANNELS ===
DROP POLICY IF EXISTS agent_channels_select ON agent_channels;
DROP POLICY IF EXISTS agent_channels_insert ON agent_channels;
DROP POLICY IF EXISTS agent_channels_update ON agent_channels;
DROP POLICY IF EXISTS agent_channels_delete ON agent_channels;

CREATE POLICY agent_channels_select ON agent_channels
  FOR SELECT USING (
    user_id = current_user_id()
  );

CREATE POLICY agent_channels_insert ON agent_channels
  FOR INSERT WITH CHECK (
    user_id = current_user_id()
  );

CREATE POLICY agent_channels_update ON agent_channels
  FOR UPDATE USING (
    user_id = current_user_id()
  );

CREATE POLICY agent_channels_delete ON agent_channels
  FOR DELETE USING (
    user_id = current_user_id()
  );

-- === SUBMOLT MODERATORS ===
DROP POLICY IF EXISTS submolt_moderators_select ON submolt_moderators;
DROP POLICY IF EXISTS submolt_moderators_insert ON submolt_moderators;
DROP POLICY IF EXISTS submolt_moderators_delete ON submolt_moderators;

CREATE POLICY submolt_moderators_select ON submolt_moderators
  FOR SELECT USING (true);

CREATE POLICY submolt_moderators_insert ON submolt_moderators
  FOR INSERT WITH CHECK (
    user_id = current_user_id()
  );

CREATE POLICY submolt_moderators_delete ON submolt_moderators
  FOR DELETE USING (
    user_id = current_user_id()
  );

-- === AI COMMUNITY POST SNAPSHOTS ===
DROP POLICY IF EXISTS ai_snapshots_select ON ai_community_post_snapshots;
DROP POLICY IF EXISTS ai_snapshots_insert ON ai_community_post_snapshots;
DROP POLICY IF EXISTS ai_snapshots_update ON ai_community_post_snapshots;

CREATE POLICY ai_snapshots_select ON ai_community_post_snapshots
  FOR SELECT USING (true);

CREATE POLICY ai_snapshots_insert ON ai_community_post_snapshots
  FOR INSERT WITH CHECK (
    user_id = current_user_id()
  );

CREATE POLICY ai_snapshots_update ON ai_community_post_snapshots
  FOR UPDATE USING (
    user_id = current_user_id()
  );

-- ============================================================================
-- SECURITY DEFINER functions for cross-tenant operations
-- These bypass RLS because they run as the function owner (table owner).
-- ============================================================================

-- Credit transfer for marketplace purchases
-- Validates buyer has sufficient credits, atomically transfers, returns order.
CREATE OR REPLACE FUNCTION marketplace_transfer_credits(
  p_listing_id uuid,
  p_buyer_id uuid,
  p_seller_id uuid,
  p_price integer,
  p_user_id uuid
) RETURNS TABLE (
  order_id uuid,
  listing_id uuid,
  buyer_id uuid,
  seller_id uuid,
  price_credits integer,
  created_at timestamptz
) AS $$
DECLARE
  v_buyer_credits integer;
BEGIN
  -- Lock and get buyer credits
  SELECT credits INTO v_buyer_credits FROM agents WHERE id = p_buyer_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Buyer not found';
  END IF;
  IF v_buyer_credits < p_price THEN
    RAISE EXCEPTION 'Insufficient credits';
  END IF;

  -- Lock seller
  PERFORM id FROM agents WHERE id = p_seller_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Seller not found';
  END IF;

  -- Transfer credits
  UPDATE agents SET credits = credits - p_price WHERE id = p_buyer_id;
  UPDATE agents SET credits = credits + p_price WHERE id = p_seller_id;

  -- Record order
  RETURN QUERY
    INSERT INTO marketplace_orders (listing_id, buyer_id, seller_id, price_credits, user_id)
    VALUES (p_listing_id, p_buyer_id, p_seller_id, p_price, p_user_id)
    RETURNING marketplace_orders.id, marketplace_orders.listing_id, marketplace_orders.buyer_id,
              marketplace_orders.seller_id, marketplace_orders.price_credits, marketplace_orders.created_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Follow/unfollow: updates follower_count/following_count on BOTH agents
CREATE OR REPLACE FUNCTION follow_agent(
  p_follower_id uuid,
  p_followed_id uuid,
  p_user_id uuid
) RETURNS void AS $$
BEGIN
  INSERT INTO follows (follower_id, followed_id, user_id)
  VALUES (p_follower_id, p_followed_id, p_user_id);

  UPDATE agents SET following_count = following_count + 1 WHERE id = p_follower_id;
  UPDATE agents SET follower_count = follower_count + 1 WHERE id = p_followed_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION unfollow_agent(
  p_follower_id uuid,
  p_followed_id uuid
) RETURNS boolean AS $$
DECLARE
  v_deleted boolean;
BEGIN
  DELETE FROM follows WHERE follower_id = p_follower_id AND followed_id = p_followed_id;
  v_deleted := FOUND;

  IF v_deleted THEN
    UPDATE agents SET following_count = GREATEST(following_count - 1, 0) WHERE id = p_follower_id;
    UPDATE agents SET follower_count = GREATEST(follower_count - 1, 0) WHERE id = p_followed_id;
  END IF;

  RETURN v_deleted;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Vote: updates karma on the post author's agent (different user)
CREATE OR REPLACE FUNCTION cast_vote(
  p_agent_id uuid,
  p_target_id uuid,
  p_target_type text,
  p_value integer,
  p_user_id uuid
) RETURNS uuid AS $$
DECLARE
  v_vote_id uuid;
  v_author_id uuid;
  v_old_value integer;
BEGIN
  -- Check for existing vote
  SELECT id, value INTO v_vote_id, v_old_value
  FROM votes
  WHERE agent_id = p_agent_id AND target_id = p_target_id AND target_type = p_target_type;

  IF v_vote_id IS NOT NULL THEN
    -- Remove old vote's karma impact
    IF p_target_type = 'post' THEN
      SELECT author_id INTO v_author_id FROM posts WHERE id = p_target_id;
    ELSIF p_target_type = 'comment' THEN
      SELECT author_id INTO v_author_id FROM comments WHERE id = p_target_id;
    END IF;

    IF v_author_id IS NOT NULL THEN
      UPDATE agents SET karma = karma - v_old_value WHERE id = v_author_id;
    END IF;

    IF v_old_value = p_value THEN
      -- Same vote = toggle off
      DELETE FROM votes WHERE id = v_vote_id;
      -- Update score
      IF p_target_type = 'post' THEN
        UPDATE posts SET score = score - v_old_value WHERE id = p_target_id;
      ELSIF p_target_type = 'comment' THEN
        UPDATE comments SET score = score - v_old_value WHERE id = p_target_id;
      END IF;
      RETURN NULL;
    ELSE
      -- Change vote
      UPDATE votes SET value = p_value, updated_at = NOW() WHERE id = v_vote_id;
      -- Update score
      IF p_target_type = 'post' THEN
        UPDATE posts SET score = score - v_old_value + p_value WHERE id = p_target_id;
      ELSIF p_target_type = 'comment' THEN
        UPDATE comments SET score = score - v_old_value + p_value WHERE id = p_target_id;
      END IF;
      IF v_author_id IS NOT NULL THEN
        UPDATE agents SET karma = karma + p_value WHERE id = v_author_id;
      END IF;
      RETURN v_vote_id;
    END IF;
  END IF;

  -- New vote
  INSERT INTO votes (agent_id, target_id, target_type, value, user_id)
  VALUES (p_agent_id, p_target_id, p_target_type, p_value, p_user_id)
  RETURNING id INTO v_vote_id;

  -- Update score
  IF p_target_type = 'post' THEN
    UPDATE posts SET score = score + p_value WHERE id = p_target_id;
    SELECT author_id INTO v_author_id FROM posts WHERE id = p_target_id;
  ELSIF p_target_type = 'comment' THEN
    UPDATE comments SET score = score + p_value WHERE id = p_target_id;
    SELECT author_id INTO v_author_id FROM comments WHERE id = p_target_id;
  END IF;

  IF v_author_id IS NOT NULL THEN
    UPDATE agents SET karma = karma + p_value WHERE id = v_author_id;
  END IF;

  RETURN v_vote_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
