-- Migration 014: Multi-tenant isolation — Add user_id to social tables + Row-Level Security
-- This migration adds user_id to all content tables and enables RLS to ensure
-- complete data isolation between tenants.
--
-- Design note: user_id is denormalized onto content tables (posts, comments, etc.)
-- for performance. Without denormalization, every query would need a JOIN through
-- agents to determine ownership. RLS policies filter on user_id directly.

BEGIN;

-- ============================================================================
-- 1. ADD user_id COLUMNS TO SOCIAL/CONTENT TABLES
-- ============================================================================

-- Posts: add user_id (owner of the agent that authored the post)
ALTER TABLE posts ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id) WHERE user_id IS NOT NULL;

-- Comments: add user_id
ALTER TABLE comments ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON comments(user_id) WHERE user_id IS NOT NULL;

-- Votes: add user_id
ALTER TABLE votes ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_votes_user_id ON votes(user_id) WHERE user_id IS NOT NULL;

-- Follows: add user_id (owner of the follower agent)
ALTER TABLE follows ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_follows_user_id ON follows(user_id) WHERE user_id IS NOT NULL;

-- Subscriptions: add user_id
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id) WHERE user_id IS NOT NULL;

-- Marketplace listings: add user_id
ALTER TABLE marketplace_listings ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_marketplace_listings_user_id ON marketplace_listings(user_id) WHERE user_id IS NOT NULL;

-- Marketplace orders: add user_id (the buyer's owner)
ALTER TABLE marketplace_orders ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_marketplace_orders_user_id ON marketplace_orders(user_id) WHERE user_id IS NOT NULL;

-- Communities: add user_id (creator's owner). Nullable because communities can be system-created.
ALTER TABLE communities ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_communities_user_id ON communities(user_id) WHERE user_id IS NOT NULL;

-- Community moderators: add user_id
ALTER TABLE community_moderators ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_community_moderators_user_id ON community_moderators(user_id) WHERE user_id IS NOT NULL;

-- AI community post snapshots: add user_id
ALTER TABLE ai_community_post_snapshots ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_ai_community_post_snapshots_user_id ON ai_community_post_snapshots(user_id) WHERE user_id IS NOT NULL;

-- ============================================================================
-- 2. BACKFILL user_id FROM agents TABLE
-- ============================================================================
-- For existing rows, derive user_id from the agent's user_id via the FK.

UPDATE posts SET user_id = a.user_id
FROM agents a WHERE posts.author_id = a.id AND posts.user_id IS NULL AND a.user_id IS NOT NULL;

UPDATE comments SET user_id = a.user_id
FROM agents a WHERE comments.author_id = a.id AND comments.user_id IS NULL AND a.user_id IS NOT NULL;

UPDATE votes SET user_id = a.user_id
FROM agents a WHERE votes.agent_id = a.id AND votes.user_id IS NULL AND a.user_id IS NOT NULL;

UPDATE follows SET user_id = a.user_id
FROM agents a WHERE follows.follower_id = a.id AND follows.user_id IS NULL AND a.user_id IS NOT NULL;

UPDATE subscriptions SET user_id = a.user_id
FROM agents a WHERE subscriptions.agent_id = a.id AND subscriptions.user_id IS NULL AND a.user_id IS NOT NULL;

UPDATE marketplace_listings SET user_id = a.user_id
FROM agents a WHERE marketplace_listings.agent_id = a.id AND marketplace_listings.user_id IS NULL AND a.user_id IS NOT NULL;

UPDATE marketplace_orders SET user_id = a.user_id
FROM agents a WHERE marketplace_orders.buyer_id = a.id AND marketplace_orders.user_id IS NULL AND a.user_id IS NOT NULL;

UPDATE communities SET user_id = a.user_id
FROM agents a WHERE communities.creator_id = a.id AND communities.user_id IS NULL AND a.user_id IS NOT NULL;

UPDATE community_moderators SET user_id = a.user_id
FROM agents a WHERE community_moderators.agent_id = a.id AND community_moderators.user_id IS NULL AND a.user_id IS NOT NULL;

UPDATE ai_community_post_snapshots SET user_id = p.user_id
FROM posts p WHERE ai_community_post_snapshots.post_id = p.id
AND ai_community_post_snapshots.user_id IS NULL AND p.user_id IS NOT NULL;

COMMIT;
