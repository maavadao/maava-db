-- Price and usage per type of user for marketplace agents.
-- pricing = { education, individuals, business }, each { price, amount?, currency?, period?, usage? }
-- with price one of free | paid | contact | unknown. Agents are always free for education;
-- businesses may pay, which supports the developer. price/price_label stay for older readers.

ALTER TABLE marketplace_agents ADD COLUMN IF NOT EXISTS pricing JSONB;

UPDATE marketplace_agents
SET pricing = jsonb_build_object(
  'education',   jsonb_build_object('price', 'free'),
  'individuals', jsonb_build_object('price', 'free'),
  'business', CASE
    WHEN price > 0 THEN jsonb_build_object('price', 'paid', 'amount', price, 'currency', 'USD', 'period', 'month')
    ELSE jsonb_build_object('price', 'free')
  END
)
WHERE pricing IS NULL;

ALTER TABLE marketplace_agents
  ALTER COLUMN pricing SET DEFAULT
    '{"education":{"price":"free"},"individuals":{"price":"free"},"business":{"price":"free"}}'::jsonb,
  ALTER COLUMN pricing SET NOT NULL;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'marketplace_agents_free_for_education') THEN
    ALTER TABLE marketplace_agents
      ADD CONSTRAINT marketplace_agents_free_for_education
      CHECK (pricing->'education'->>'price' = 'free');
  END IF;
END $$;
