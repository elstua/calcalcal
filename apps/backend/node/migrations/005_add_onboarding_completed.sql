-- Migration: Add onboarding_completed field to user_profiles table
-- Tracks whether user has completed the onboarding flow

-- Add onboarding_completed column to user_profiles
ALTER TABLE "public"."user_profiles" 
ADD COLUMN IF NOT EXISTS "onboarding_completed" BOOLEAN DEFAULT FALSE;

-- Add index for performance on onboarding_completed queries
-- Useful for analytics and filtering users who haven't completed onboarding
CREATE INDEX IF NOT EXISTS "idx_user_profiles_onboarding_completed" 
ON "public"."user_profiles" USING "btree" ("onboarding_completed");

