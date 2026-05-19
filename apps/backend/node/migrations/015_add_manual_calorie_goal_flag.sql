-- Migration 015: Track whether the daily calorie goal is user-entered.
--
-- When false, health profile changes can recalculate daily_calorie_goal.
-- When true, health profile changes keep the user's calorie limit and only
-- recalculate derived macro goals around that limit.

ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS "daily_calorie_goal_is_manual" boolean NOT NULL DEFAULT false;
