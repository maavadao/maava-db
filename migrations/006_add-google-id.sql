-- Add google_id column (used by Go auth service for Google OAuth)
ALTER TABLE users
ADD COLUMN IF NOT EXISTS google_id VARCHAR UNIQUE;
