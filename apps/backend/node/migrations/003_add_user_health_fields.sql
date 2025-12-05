-- Add user health and profile fields for calorie calculation
-- All fields are optional (nullable) for backward compatibility

ALTER TABLE "public"."user_profiles"
  ADD COLUMN IF NOT EXISTS "weight_kg" numeric,
  ADD COLUMN IF NOT EXISTS "height_cm" numeric,
  ADD COLUMN IF NOT EXISTS "age" integer,
  ADD COLUMN IF NOT EXISTS "activity_level" text,
  ADD COLUMN IF NOT EXISTS "target_weight_kg" numeric,
  ADD COLUMN IF NOT EXISTS "gender" text,
  ADD COLUMN IF NOT EXISTS "weight_unit" text DEFAULT 'kg',
  ADD COLUMN IF NOT EXISTS "height_unit" text DEFAULT 'cm';

-- Add CHECK constraints for enum-like fields
ALTER TABLE "public"."user_profiles"
  DROP CONSTRAINT IF EXISTS "user_profiles_activity_level_check",
  ADD CONSTRAINT "user_profiles_activity_level_check" 
    CHECK (("activity_level" IS NULL) OR ("activity_level" = ANY (ARRAY['small'::"text", 'moderate'::"text", 'active'::"text"])));

ALTER TABLE "public"."user_profiles"
  DROP CONSTRAINT IF EXISTS "user_profiles_gender_check",
  ADD CONSTRAINT "user_profiles_gender_check" 
    CHECK (("gender" IS NULL) OR ("gender" = ANY (ARRAY['male'::"text", 'female'::"text", 'other'::"text"])));

ALTER TABLE "public"."user_profiles"
  DROP CONSTRAINT IF EXISTS "user_profiles_weight_unit_check",
  ADD CONSTRAINT "user_profiles_weight_unit_check" 
    CHECK (("weight_unit" = ANY (ARRAY['kg'::"text", 'lbs'::"text"])));

ALTER TABLE "public"."user_profiles"
  DROP CONSTRAINT IF EXISTS "user_profiles_height_unit_check",
  ADD CONSTRAINT "user_profiles_height_unit_check" 
    CHECK (("height_unit" = ANY (ARRAY['cm'::"text", 'in'::"text"])));

