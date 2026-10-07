-- 022: Barrsa Seller Agent — full data model for product listing,
--      social publishing, approval workflows, and recurring promotion.
--
-- Tables: seller_profiles, seller_categories, products, product_versions,
--         product_assets, listing_outputs, connected_social_accounts,
--         publishing_targets, publishing_jobs, publishing_results,
--         approval_requests, promotion_rules, campaign_runs

-- ═══════════════════════════════════════════════════════════════════════════
-- Prerequisite: ensure uuid-ossp is available (already present from 001)
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- seller_categories — normalized taxonomy
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS seller_categories (
  id          UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  slug        TEXT         NOT NULL UNIQUE,
  name        TEXT         NOT NULL,
  description TEXT,
  parent_id   UUID         REFERENCES seller_categories(id) ON DELETE SET NULL,
  sort_order  INT          DEFAULT 0,
  is_active   BOOLEAN      DEFAULT true,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Seed default categories
INSERT INTO seller_categories (slug, name, description, sort_order) VALUES
  ('design_logo',       'Design & Logo Services',     'Logo design, branding, visual identity',         1),
  ('digital_product',   'Digital Products',            'E-books, templates, courses, presets',            2),
  ('software',          'Software & Code',             'SaaS tools, scripts, plugins, APIs, bots',       3),
  ('creative_services', 'Creative Services',           'Writing, video editing, music, illustration',     4),
  ('consulting',        'Consulting & Coaching',       'Business, tech, career coaching',                 5),
  ('marketing',         'Marketing & Social Media',    'Social management, SEO, ad campaigns',            6)
ON CONFLICT (slug) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════
-- seller_profiles — one per user, stores brand voice + preferences
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS seller_profiles (
  id                    UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID         NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  category_id           UUID         REFERENCES seller_categories(id) ON DELETE SET NULL,
  business_name         TEXT,
  brand_voice           TEXT,                -- e.g. "professional", "casual", "playful"
  tagline               TEXT,
  target_audience       TEXT,
  default_cta           TEXT,                -- default call-to-action
  approval_required     BOOLEAN      DEFAULT true,
  auto_publish_channels TEXT[]       DEFAULT '{}',   -- channel slugs allowed for auto-publish
  timezone              TEXT         DEFAULT 'UTC',
  logo_url              TEXT,
  website_url           TEXT,
  metadata              JSONB        DEFAULT '{}',
  is_active             BOOLEAN      DEFAULT true,
  onboarding_completed  BOOLEAN      DEFAULT false,
  created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sp_user_id ON seller_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_sp_category_id ON seller_profiles(category_id);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_sp_updated_at') THEN
    CREATE TRIGGER trg_sp_updated_at
      BEFORE UPDATE ON seller_profiles
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- products — canonical product/service record
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS products (
  id                UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  seller_profile_id UUID         NOT NULL REFERENCES seller_profiles(id) ON DELETE CASCADE,
  category_id       UUID         REFERENCES seller_categories(id) ON DELETE SET NULL,
  name              TEXT         NOT NULL,
  summary           TEXT,               -- one-line summary
  description       TEXT,               -- full description
  price             NUMERIC(12,2),
  pricing_model     TEXT         CHECK (pricing_model IN ('one_time', 'subscription', 'custom', 'free', 'contact')),
  currency          TEXT         DEFAULT 'USD',
  deliverables      TEXT[],             -- list of what buyer gets
  target_audience   TEXT,
  tags              TEXT[]       DEFAULT '{}',
  status            TEXT         NOT NULL DEFAULT 'draft'
                                 CHECK (status IN ('draft', 'active', 'paused', 'archived')),
  metadata          JSONB        DEFAULT '{}',
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_products_user_id ON products(user_id);
CREATE INDEX IF NOT EXISTS idx_products_seller_profile ON products(seller_profile_id);
CREATE INDEX IF NOT EXISTS idx_products_status ON products(status) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_products_updated_at') THEN
    CREATE TRIGGER trg_products_updated_at
      BEFORE UPDATE ON products
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- product_versions — generated listing variants and revisions
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS product_versions (
  id           UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id   UUID         NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  version_num  INT          NOT NULL DEFAULT 1,
  title        TEXT         NOT NULL,
  description  TEXT,
  bullets      TEXT[],            -- selling points
  cta          TEXT,              -- call-to-action
  hashtags     TEXT[]       DEFAULT '{}',
  tone         TEXT,              -- detected/requested tone
  generated_by TEXT,              -- 'ai', 'manual', 'hybrid'
  is_current   BOOLEAN      DEFAULT false,
  metadata     JSONB        DEFAULT '{}',
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pv_product_id ON product_versions(product_id);
CREATE INDEX IF NOT EXISTS idx_pv_current ON product_versions(product_id) WHERE is_current = true;

-- ═══════════════════════════════════════════════════════════════════════════
-- product_assets — uploaded or generated visuals, thumbnails, mockups
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS product_assets (
  id           UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id   UUID         NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  user_id      UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  asset_type   TEXT         NOT NULL CHECK (asset_type IN (
                              'image', 'thumbnail', 'mockup', 'promo_card',
                              'video', 'document', 'other'
                            )),
  file_url     TEXT         NOT NULL,
  file_name    TEXT,
  file_size    BIGINT,
  mime_type    TEXT,
  width        INT,
  height       INT,
  is_generated BOOLEAN      DEFAULT false,
  generation_prompt TEXT,          -- if AI-generated, the prompt used
  sort_order   INT          DEFAULT 0,
  metadata     JSONB        DEFAULT '{}',
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pa_product_id ON product_assets(product_id);
CREATE INDEX IF NOT EXISTS idx_pa_user_id ON product_assets(user_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- listing_outputs — final marketplace-ready copy for each channel
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS listing_outputs (
  id                UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id        UUID         NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  product_version_id UUID        REFERENCES product_versions(id) ON DELETE SET NULL,
  channel           TEXT         NOT NULL,  -- 'marketplace', 'facebook_page', 'instagram', 'linkedin', 'short_promo', 'story_caption', 'followup'
  title             TEXT,
  body              TEXT,
  cta               TEXT,
  hashtags          TEXT[]       DEFAULT '{}',
  media_urls        TEXT[]       DEFAULT '{}',
  metadata          JSONB        DEFAULT '{}',
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lo_product_id ON listing_outputs(product_id);
CREATE INDEX IF NOT EXISTS idx_lo_channel ON listing_outputs(channel);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_lo_updated_at') THEN
    CREATE TRIGGER trg_lo_updated_at
      BEFORE UPDATE ON listing_outputs
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- connected_social_accounts — per-user provider/account/page mapping
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS connected_social_accounts (
  id                UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider          TEXT         NOT NULL,  -- 'late', 'postiz', 'composio', 'direct_facebook', etc.
  provider_account_id TEXT,                  -- ID within the provider (e.g. Late profile ID)
  platform          TEXT         NOT NULL,  -- 'facebook_page', 'instagram', 'linkedin', 'twitter', 'tiktok'
  platform_account_id TEXT,                  -- page ID, account ID on the platform
  account_name      TEXT,                   -- display name of the page/account
  account_url       TEXT,
  access_token_enc  TEXT,                   -- encrypted token (never store plaintext)
  refresh_token_enc TEXT,
  token_expires_at  TIMESTAMPTZ,
  scopes            TEXT[]       DEFAULT '{}',
  is_active         BOOLEAN      DEFAULT true,
  last_used_at      TIMESTAMPTZ,
  metadata          JSONB        DEFAULT '{}',
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, provider, platform, platform_account_id)
);

CREATE INDEX IF NOT EXISTS idx_csa_user_id ON connected_social_accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_csa_provider ON connected_social_accounts(provider);
CREATE INDEX IF NOT EXISTS idx_csa_platform ON connected_social_accounts(platform);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_csa_updated_at') THEN
    CREATE TRIGGER trg_csa_updated_at
      BEFORE UPDATE ON connected_social_accounts
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- publishing_targets — configured publishing destinations per user
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS publishing_targets (
  id                    UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  social_account_id     UUID         REFERENCES connected_social_accounts(id) ON DELETE CASCADE,
  target_type           TEXT         NOT NULL,  -- 'facebook_page', 'instagram_account', 'linkedin_page', 'internal_marketplace'
  target_label          TEXT,                    -- user-friendly label
  is_default            BOOLEAN      DEFAULT false,
  is_active             BOOLEAN      DEFAULT true,
  config                JSONB        DEFAULT '{}',  -- target-specific settings
  created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pt_user_id ON publishing_targets(user_id);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_pt_updated_at') THEN
    CREATE TRIGGER trg_pt_updated_at
      BEFORE UPDATE ON publishing_targets
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- publishing_jobs — queue of pending/published/failed post jobs
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS publishing_jobs (
  id                  UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id             UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  product_id          UUID         NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  listing_output_id   UUID         REFERENCES listing_outputs(id) ON DELETE SET NULL,
  publishing_target_id UUID        REFERENCES publishing_targets(id) ON DELETE SET NULL,
  channel             TEXT         NOT NULL,
  status              TEXT         NOT NULL DEFAULT 'pending'
                                   CHECK (status IN ('pending', 'scheduled', 'publishing', 'published', 'failed', 'cancelled')),
  scheduled_at        TIMESTAMPTZ,
  published_at        TIMESTAMPTZ,
  retry_count         INT          DEFAULT 0,
  max_retries         INT          DEFAULT 3,
  last_error          TEXT,
  idempotency_key     TEXT         UNIQUE,   -- prevent duplicate publishes
  metadata            JSONB        DEFAULT '{}',
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pj_user_id ON publishing_jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_pj_product_id ON publishing_jobs(product_id);
CREATE INDEX IF NOT EXISTS idx_pj_status ON publishing_jobs(status);
CREATE INDEX IF NOT EXISTS idx_pj_scheduled ON publishing_jobs(scheduled_at)
  WHERE status = 'scheduled' AND scheduled_at IS NOT NULL;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_pj_updated_at') THEN
    CREATE TRIGGER trg_pj_updated_at
      BEFORE UPDATE ON publishing_jobs
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- publishing_results — provider post IDs, URLs, timestamps, errors
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS publishing_results (
  id                UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  publishing_job_id UUID         NOT NULL REFERENCES publishing_jobs(id) ON DELETE CASCADE,
  provider          TEXT,                   -- 'late', 'postiz', etc.
  provider_post_id  TEXT,                   -- ID from the provider
  platform_post_id  TEXT,                   -- ID on the actual platform (e.g. Facebook post ID)
  post_url          TEXT,                   -- public URL of the published post
  platform          TEXT,
  status            TEXT         DEFAULT 'success' CHECK (status IN ('success', 'partial', 'failed')),
  error_code        TEXT,
  error_message     TEXT,
  response_data     JSONB        DEFAULT '{}',
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pr_job_id ON publishing_results(publishing_job_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- approval_requests — review/approve/reject workflow
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS approval_requests (
  id                  UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id             UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  product_id          UUID         NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  product_version_id  UUID         REFERENCES product_versions(id) ON DELETE SET NULL,
  listing_output_id   UUID         REFERENCES listing_outputs(id) ON DELETE SET NULL,
  request_type        TEXT         NOT NULL CHECK (request_type IN ('listing', 'publish', 'visual', 'promotion')),
  status              TEXT         NOT NULL DEFAULT 'pending'
                                   CHECK (status IN ('pending', 'approved', 'rejected', 'expired')),
  reviewer_notes      TEXT,
  submitted_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  reviewed_at         TIMESTAMPTZ,
  expires_at          TIMESTAMPTZ,
  metadata            JSONB        DEFAULT '{}',
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ar_user_id ON approval_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_ar_product_id ON approval_requests(product_id);
CREATE INDEX IF NOT EXISTS idx_ar_status ON approval_requests(status) WHERE status = 'pending';

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_ar_updated_at') THEN
    CREATE TRIGGER trg_ar_updated_at
      BEFORE UPDATE ON approval_requests
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- promotion_rules — recurring schedules and templates
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS promotion_rules (
  id                UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  product_id        UUID         NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  rule_name         TEXT         NOT NULL,
  rule_type         TEXT         NOT NULL CHECK (rule_type IN (
                                  'repost', 'reminder', 'launch_sequence', 'weekend_promo',
                                  'still_available', 'custom'
                                )),
  schedule_cron     TEXT,                   -- cron expression for recurring
  delay_hours       INT,                    -- simple delay from product activation
  template          TEXT,                   -- text template with {{placeholders}}
  channels          TEXT[]       DEFAULT '{}',
  max_runs          INT,                    -- max executions (null = unlimited)
  is_active         BOOLEAN      DEFAULT true,
  metadata          JSONB        DEFAULT '{}',
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_prom_user_id ON promotion_rules(user_id);
CREATE INDEX IF NOT EXISTS idx_prom_product_id ON promotion_rules(product_id);
CREATE INDEX IF NOT EXISTS idx_prom_active ON promotion_rules(is_active) WHERE is_active = true;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_prom_updated_at') THEN
    CREATE TRIGGER trg_prom_updated_at
      BEFORE UPDATE ON promotion_rules
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- campaign_runs — audit log of each automation run
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS campaign_runs (
  id                  UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id             UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  promotion_rule_id   UUID         REFERENCES promotion_rules(id) ON DELETE SET NULL,
  product_id          UUID         REFERENCES products(id) ON DELETE SET NULL,
  publishing_job_id   UUID         REFERENCES publishing_jobs(id) ON DELETE SET NULL,
  run_type            TEXT         NOT NULL,  -- 'scheduled', 'manual', 'auto_repost'
  status              TEXT         NOT NULL DEFAULT 'running'
                                   CHECK (status IN ('running', 'completed', 'failed', 'skipped')),
  started_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  completed_at        TIMESTAMPTZ,
  summary             JSONB        DEFAULT '{}',  -- channels posted, errors, etc.
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cr_user_id ON campaign_runs(user_id);
CREATE INDEX IF NOT EXISTS idx_cr_promotion_rule ON campaign_runs(promotion_rule_id);
CREATE INDEX IF NOT EXISTS idx_cr_created_at ON campaign_runs(created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════
-- RLS policies for seller tables
-- All seller tables are scoped to user_id for multi-tenant isolation
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE seller_profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE products                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_versions         ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_assets           ENABLE ROW LEVEL SECURITY;
ALTER TABLE listing_outputs          ENABLE ROW LEVEL SECURITY;
ALTER TABLE connected_social_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE publishing_targets       ENABLE ROW LEVEL SECURITY;
ALTER TABLE publishing_jobs          ENABLE ROW LEVEL SECURITY;
ALTER TABLE publishing_results       ENABLE ROW LEVEL SECURITY;
ALTER TABLE approval_requests        ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotion_rules          ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaign_runs            ENABLE ROW LEVEL SECURITY;

-- Owner-only policies (user can only see/modify their own data)
CREATE POLICY seller_profiles_user_policy ON seller_profiles
  USING (user_id::text = current_setting('app.current_user_id', true))
  WITH CHECK (user_id::text = current_setting('app.current_user_id', true));

CREATE POLICY products_user_policy ON products
  USING (user_id::text = current_setting('app.current_user_id', true))
  WITH CHECK (user_id::text = current_setting('app.current_user_id', true));

CREATE POLICY product_versions_user_policy ON product_versions
  USING (product_id IN (SELECT id FROM products WHERE user_id::text = current_setting('app.current_user_id', true)));

CREATE POLICY product_assets_user_policy ON product_assets
  USING (user_id::text = current_setting('app.current_user_id', true))
  WITH CHECK (user_id::text = current_setting('app.current_user_id', true));

CREATE POLICY listing_outputs_user_policy ON listing_outputs
  USING (product_id IN (SELECT id FROM products WHERE user_id::text = current_setting('app.current_user_id', true)));

CREATE POLICY connected_social_user_policy ON connected_social_accounts
  USING (user_id::text = current_setting('app.current_user_id', true))
  WITH CHECK (user_id::text = current_setting('app.current_user_id', true));

CREATE POLICY publishing_targets_user_policy ON publishing_targets
  USING (user_id::text = current_setting('app.current_user_id', true))
  WITH CHECK (user_id::text = current_setting('app.current_user_id', true));

CREATE POLICY publishing_jobs_user_policy ON publishing_jobs
  USING (user_id::text = current_setting('app.current_user_id', true))
  WITH CHECK (user_id::text = current_setting('app.current_user_id', true));

CREATE POLICY publishing_results_user_policy ON publishing_results
  USING (publishing_job_id IN (
    SELECT id FROM publishing_jobs WHERE user_id::text = current_setting('app.current_user_id', true)
  ));

CREATE POLICY approval_requests_user_policy ON approval_requests
  USING (user_id::text = current_setting('app.current_user_id', true))
  WITH CHECK (user_id::text = current_setting('app.current_user_id', true));

CREATE POLICY promotion_rules_user_policy ON promotion_rules
  USING (user_id::text = current_setting('app.current_user_id', true))
  WITH CHECK (user_id::text = current_setting('app.current_user_id', true));

CREATE POLICY campaign_runs_user_policy ON campaign_runs
  USING (user_id::text = current_setting('app.current_user_id', true))
  WITH CHECK (user_id::text = current_setting('app.current_user_id', true));

-- Public read policy for active products on the marketplace
CREATE POLICY products_public_read ON products
  FOR SELECT USING (status = 'active');

-- seller_categories is public read
CREATE POLICY seller_categories_public_read ON seller_categories
  FOR SELECT USING (true);

-- FORCE RLS for non-superuser roles
DO $$ 
DECLARE
  tbl TEXT;
BEGIN
  FOR tbl IN SELECT unnest(ARRAY[
    'seller_profiles', 'products', 'product_versions', 'product_assets',
    'listing_outputs', 'connected_social_accounts', 'publishing_targets',
    'publishing_jobs', 'publishing_results', 'approval_requests',
    'promotion_rules', 'campaign_runs'
  ]) LOOP
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', tbl);
  END LOOP;
END $$;
