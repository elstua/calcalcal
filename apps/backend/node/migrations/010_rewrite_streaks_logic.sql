
-- Rewrite Streaks Logic Migration
-- This migration removes the complex SQL-based streak logic in favor of application-layer logic
-- It drops the triggers and functions that were causing bugs with NULL blocks

-- 1. Drop trigger on diary_entries
DROP TRIGGER IF EXISTS "update_streak_on_diary_change" ON "public"."diary_entries";

-- 2. Drop the trigger function
DROP FUNCTION IF EXISTS "public"."update_user_streak"();

-- 3. Drop the problematic content check function
DROP FUNCTION IF EXISTS "public"."has_meaningful_content"(text, jsonb);

-- 4. Add index to ai_analysis_status for efficient filtering in application-layer streak calculation
CREATE INDEX IF NOT EXISTS "idx_diary_entries_analysis_status" ON "public"."diary_entries" ("user_id", "ai_analysis_status");
