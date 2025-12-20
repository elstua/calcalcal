-- Migration: Add temporary account support
-- This allows users to start using the app immediately without OAuth authentication

-- Add columns for temporary account support
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS is_temporary BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS device_id TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS created_via TEXT; -- 'apple', 'google', 'temporary'

-- Index for cleanup operations (finding old temporary accounts)
CREATE INDEX IF NOT EXISTS idx_user_profiles_temporary_created_at 
ON user_profiles(is_temporary, created_at) 
WHERE is_temporary = TRUE;

-- Index for device_id lookups (finding existing temporary account by device)
CREATE INDEX IF NOT EXISTS idx_user_profiles_device_id 
ON user_profiles(device_id) 
WHERE device_id IS NOT NULL;

-- Update existing users to have created_via based on their OAuth provider
UPDATE user_profiles 
SET created_via = CASE 
    WHEN apple_id IS NOT NULL THEN 'apple'
    WHEN google_id IS NOT NULL THEN 'google'
    ELSE NULL
END
WHERE created_via IS NULL;
