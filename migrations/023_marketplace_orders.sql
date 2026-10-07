-- 023: Product Orders — order tracking, payment status, and delivery
--      for the Barrsa × PaySponge economy system.
--
-- Tables: product_orders  (separate from marketplace_orders which is the
--         agent-to-agent credits marketplace from 001_schema.sql)
-- Supports: seller products purchased by buyers (human or AI agent),
--           PaySponge USDC payments, and digital product delivery.

-- ═══════════════════════════════════════════════════════════════════════════
-- product_orders — purchase records with payment + delivery tracking
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS product_orders (
  id                UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id        UUID         NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  seller_user_id    UUID         NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  buyer_user_id     UUID         REFERENCES users(id) ON DELETE SET NULL,   -- NULL for guest/external buyers
  buyer_agent_id    TEXT,                                                    -- OpenClaw agent ID if AI buyer

  -- Payment
  amount            NUMERIC(12,2) NOT NULL,
  currency          TEXT          DEFAULT 'USDC',
  payment_link_id   TEXT,                                                    -- PaySponge payment link ID
  payment_status    TEXT          NOT NULL DEFAULT 'pending'
                                  CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded', 'expired')),
  payment_tx_hash   TEXT,                                                    -- blockchain tx hash
  payment_chain     TEXT,                                                    -- base, solana, etc.
  paid_at           TIMESTAMPTZ,

  -- Delivery
  delivery_status   TEXT          NOT NULL DEFAULT 'pending'
                                  CHECK (delivery_status IN ('pending', 'delivered', 'failed')),
  delivered_at      TIMESTAMPTZ,
  delivery_data     JSONB,                                                   -- download link, access key, etc.

  -- Lifecycle
  status            TEXT          NOT NULL DEFAULT 'created'
                                  CHECK (status IN ('created', 'confirmed', 'completed', 'cancelled', 'disputed')),
  notes             TEXT,
  metadata          JSONB         DEFAULT '{}',
  created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_po_product_id       ON product_orders(product_id);
CREATE INDEX IF NOT EXISTS idx_po_seller_user_id   ON product_orders(seller_user_id);
CREATE INDEX IF NOT EXISTS idx_po_buyer_user_id    ON product_orders(buyer_user_id);
CREATE INDEX IF NOT EXISTS idx_po_payment_status   ON product_orders(payment_status);
CREATE INDEX IF NOT EXISTS idx_po_payment_link     ON product_orders(payment_link_id);
CREATE INDEX IF NOT EXISTS idx_po_status           ON product_orders(status);
CREATE INDEX IF NOT EXISTS idx_po_created_at       ON product_orders(created_at DESC);

-- updated_at trigger
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_po_updated_at') THEN
    CREATE TRIGGER trg_po_updated_at
      BEFORE UPDATE ON product_orders
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- RLS — product_orders
-- Sellers can see orders for their products; buyers can see their purchases.
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE product_orders ENABLE ROW LEVEL SECURITY;

-- Sellers see their sales
CREATE POLICY po_seller_policy ON product_orders
  FOR ALL
  USING (seller_user_id::text = current_setting('app.current_user_id', true))
  WITH CHECK (seller_user_id::text = current_setting('app.current_user_id', true));

-- Buyers see their purchases
CREATE POLICY po_buyer_policy ON product_orders
  FOR SELECT
  USING (buyer_user_id::text = current_setting('app.current_user_id', true));

-- Service-level access for webhooks (e.g. PaySponge payment callbacks).
-- Allows full access when app.service_role is set to 'webhook'.
CREATE POLICY po_service_policy ON product_orders
  FOR ALL
  USING (current_setting('app.service_role', true) = 'webhook')
  WITH CHECK (current_setting('app.service_role', true) = 'webhook');

-- Force RLS
ALTER TABLE product_orders FORCE ROW LEVEL SECURITY;
