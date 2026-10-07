-- Add enhanced product metadata columns for chat-originated product creation.
-- These columns support the dual-channel (user-visible + machine-writable) response model.

-- source_context: captures conversation context that led to product creation
ALTER TABLE products ADD COLUMN IF NOT EXISTS source_context JSONB DEFAULT NULL;

-- requires_review: flag products that need human review (missing required fields, low confidence, etc.)
ALTER TABLE products ADD COLUMN IF NOT EXISTS requires_review BOOLEAN DEFAULT false;

-- missing_fields: list of field names the AI could not fill
ALTER TABLE products ADD COLUMN IF NOT EXISTS missing_fields TEXT[] DEFAULT '{}';

-- idempotency_key: prevents duplicate product creation from retried chat messages
ALTER TABLE products ADD COLUMN IF NOT EXISTS idempotency_key TEXT DEFAULT NULL;

-- workspace_snapshot_path: path to the JSON snapshot in the user's workspace
ALTER TABLE products ADD COLUMN IF NOT EXISTS workspace_snapshot_path TEXT DEFAULT NULL;

-- bucket_snapshot_path: full GCS path to the snapshot file
ALTER TABLE products ADD COLUMN IF NOT EXISTS bucket_snapshot_path TEXT DEFAULT NULL;

-- product_type: broader classification beyond pricing_model
ALTER TABLE products ADD COLUMN IF NOT EXISTS product_type TEXT DEFAULT NULL;

-- Partial unique index on idempotency_key per user (for dedup)
CREATE UNIQUE INDEX IF NOT EXISTS idx_products_idempotency_key
  ON products (user_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;
