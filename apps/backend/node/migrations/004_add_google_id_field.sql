-- Migration: Add google_id field to user_profiles table for Google Sign-In support
-- Similar to existing apple_id field structure

-- Add google_id column to user_profiles
ALTER TABLE "public"."user_profiles" 
ADD COLUMN IF NOT EXISTS "google_id" TEXT UNIQUE;

-- Add index for performance on google_id lookups
CREATE INDEX IF NOT EXISTS "idx_user_profiles_google_id" ON "public"."user_profiles" USING "btree" ("google_id");

