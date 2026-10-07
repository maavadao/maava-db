-- Add microsoft_id column (used by Go auth service for Microsoft OAuth)
ALTER TABLE users
ADD COLUMN IF NOT EXISTS microsoft_id VARCHAR UNIQUE;
