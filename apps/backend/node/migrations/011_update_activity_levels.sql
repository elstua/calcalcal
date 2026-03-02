-- Migration 011: Update activity level constraint for expanded levels
-- Adds: sedentary, light, very_active
-- Keeps: small (backward compat), moderate, active

ALTER TABLE "public"."user_profiles"
  DROP CONSTRAINT IF EXISTS "user_profiles_activity_level_check",
  ADD CONSTRAINT "user_profiles_activity_level_check"
    CHECK (("activity_level" IS NULL) OR ("activity_level" = ANY (
      ARRAY['sedentary'::"text", 'light'::"text", 'moderate'::"text",
            'active'::"text", 'very_active'::"text", 'small'::"text"]
    )));
