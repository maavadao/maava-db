-- 033: Add physical product categories and product_type column
-- Expands the platform beyond digital-only to support physical products

-- ═══════════════════════════════════════════════════════════════════════════
-- New seller categories for physical products
-- ═══════════════════════════════════════════════════════════════════════════
INSERT INTO seller_categories (slug, name, description, sort_order) VALUES
  ('health_fitness',     'Health & Fitness',            'Supplements, fitness gear, wellness products',               7),
  ('fashion_apparel',    'Fashion & Apparel',           'Clothing, shoes, accessories, jewelry',                      8),
  ('electronics',        'Electronics & Gadgets',       'Devices, components, accessories, smart home',               9),
  ('home_living',        'Home & Living',               'Furniture, decor, kitchen, garden',                         10),
  ('beauty_personal',    'Beauty & Personal Care',      'Skincare, makeup, haircare, grooming',                      11),
  ('food_beverage',      'Food & Beverage',             'Snacks, drinks, specialty food, meal kits',                 12),
  ('sports_outdoors',    'Sports & Outdoors',           'Equipment, gear, camping, recreation',                      13),
  ('toys_hobbies',       'Toys & Hobbies',              'Games, collectibles, crafts, hobby supplies',               14),
  ('automotive',         'Automotive & Parts',          'Car accessories, parts, tools, cleaning',                   15),
  ('pet_supplies',       'Pet Supplies',                'Food, toys, accessories, health products for pets',         16),
  ('handmade',           'Handmade & Custom',           'Artisan goods, custom orders, one-of-a-kind items',        17),
  ('general_merchandise','General Merchandise',         'Other physical products not in a specific category',        18)
ON CONFLICT (slug) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════
-- Add product_type column to products table (if not already present)
-- Values: digital, physical, service, hybrid
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'products' AND column_name = 'product_type'
  ) THEN
    ALTER TABLE products
      ADD COLUMN product_type TEXT DEFAULT 'digital'
      CHECK (product_type IN ('digital', 'physical', 'service', 'hybrid'));
  END IF;
END $$;
