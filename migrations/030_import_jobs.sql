-- Import Jobs table for marketplace product imports
-- Tracks async import pipeline: queued → running → saving_raw_file → uploading_to_bucket → ingesting_to_db → completed/failed

CREATE TABLE IF NOT EXISTS import_jobs (
  id                  UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id             UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  seller_profile_id   UUID         REFERENCES seller_profiles(id) ON DELETE SET NULL,
  submitted_links     TEXT[]       NOT NULL DEFAULT '{}',
  status              TEXT         NOT NULL DEFAULT 'queued'
                                   CHECK (status IN ('queued','running','saving_raw_file','uploading_to_bucket','ingesting_to_db','completed','failed')),
  raw_workspace_path  TEXT,
  raw_bucket_path     TEXT,
  product_count       INTEGER      DEFAULT 0,
  error_count         INTEGER      DEFAULT 0,
  error_message       TEXT,
  started_at          TIMESTAMPTZ,
  completed_at        TIMESTAMPTZ,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_import_jobs_user_id ON import_jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_import_jobs_status ON import_jobs(status);

-- Unique partial index on products for dedup by source_product_url per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_products_user_source_url
  ON products (user_id, (metadata->>'source_product_url'))
  WHERE metadata->>'source_product_url' IS NOT NULL
    AND metadata->>'source_product_url' != '';
