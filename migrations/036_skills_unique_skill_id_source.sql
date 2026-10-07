-- 036_skills_unique_skill_id_source.sql
--
-- The tenant-dashboard /api/skills route runs:
--   INSERT INTO skills (...) VALUES (...) ON CONFLICT (skill_id, source) DO NOTHING
-- but the skills table only has a UNIQUE on the surrogate `id` column, so
-- Postgres fails with: "there is no unique or exclusion constraint matching
-- the ON CONFLICT specification" → /api/skills?installed=true returns 500.
--
-- This migration deduplicates any existing rows that share (skill_id, source)
-- and then adds the missing UNIQUE constraint so ON CONFLICT works.

BEGIN;

-- Drop duplicate rows, keeping the highest-installs / oldest record.
WITH ranked AS (
    SELECT
        id,
        ROW_NUMBER() OVER (
            PARTITION BY skill_id, source
            ORDER BY installs DESC NULLS LAST, created_at ASC, id ASC
        ) AS rn
    FROM skills
)
DELETE FROM skills s
USING ranked r
WHERE s.id = r.id
  AND r.rn > 1;

-- Add the unique constraint that the application's ON CONFLICT clause expects.
ALTER TABLE skills
    ADD CONSTRAINT skills_skill_id_source_key UNIQUE (skill_id, source);

COMMIT;
