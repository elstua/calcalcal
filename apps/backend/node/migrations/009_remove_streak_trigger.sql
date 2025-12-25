-- Migration: Remove streak trigger
-- The trigger has a bug with unscoped column references and duplicates
-- application-level logic. We now rely on StreakCalculator.updateStreaksOnEntryChange()
-- which is called from the diary routes.

-- Drop the trigger
DROP TRIGGER IF EXISTS "update_streak_on_diary_change" ON "public"."diary_entries";

-- Drop the trigger function
DROP FUNCTION IF EXISTS "public"."update_user_streak"();

-- Drop the has_meaningful_content function (logic is in StreakCalculator.hasMeaningfulContent)
DROP FUNCTION IF EXISTS "public"."has_meaningful_content"("text", "jsonb");
