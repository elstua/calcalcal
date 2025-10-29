-- Calcalcal initial schema for vanilla PostgreSQL (Supabase-specific parts removed)
-- This preserves tables, functions, triggers, indexes from public_schema.sql
-- and omits Supabase RLS policies, GRANTs to anon/authenticated/service_role,
-- and foreign keys referencing auth.users.

BEGIN;

-- Ensure required extension for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Schema (public exists by default, but keep for clarity)
CREATE SCHEMA IF NOT EXISTS "public";

-- Functions
CREATE OR REPLACE FUNCTION "public"."calculate_diary_totals"("blocks_json" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql"
AS $$
declare totals jsonb; begin
  select jsonb_build_object(
    'total_calories', coalesce(sum((block->>'calories')::integer), 0),
    'total_protein',  coalesce(sum((block->>'protein')::decimal), 0.0),
    'total_fat',      coalesce(sum((block->>'fat')::decimal), 0.0),
    'total_carbs',    coalesce(sum((block->>'carbs')::decimal), 0.0),
    'total_fiber',    coalesce(sum((block->>'fiber')::decimal), 0.0),
    'total_sugar',    coalesce(sum((block->>'sugar')::decimal), 0.0),
    'total_sodium',   coalesce(sum((block->>'sodium')::decimal), 0.0)
  ) into totals
  from jsonb_array_elements(blocks_json) as block;
  return totals;
end; $$;

CREATE OR REPLACE FUNCTION "public"."parse_content_into_blocks"("content_text" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql"
AS $$
declare
  blocks jsonb := '[]'::jsonb;
  paragraphs text[];
  paragraph text;
  block_count integer := 0;
begin
  paragraphs := string_to_array(content_text, E'\n\n');
  foreach paragraph in array paragraphs loop
    if trim(paragraph) <> '' then
      block_count := block_count + 1;
      blocks := blocks || jsonb_build_object(
        'id', gen_random_uuid()::text,
        'position', block_count,
        'content', trim(paragraph),
        'type', 'text',
        'calories', 0,
        'protein', 0.0,
        'fat', 0.0,
        'carbs', 0.0,
        'fiber', 0.0,
        'sugar', 0.0,
        'sodium', 0.0,
        'confidence', 0.0,
        'ai_analysis', null,
        'created_at', now()
      );
    end if;
  end loop;
  return blocks;
end; $$;

CREATE OR REPLACE FUNCTION "public"."set_diary_entry_content_derived"() RETURNS "trigger"
    LANGUAGE "plpgsql"
AS $$
declare
  new_blocks jsonb;
  new_totals jsonb;
begin
  if TG_OP = 'INSERT' or (TG_OP = 'UPDATE' and (old.content is distinct from new.content)) then
    new_blocks := public.parse_content_into_blocks(coalesce(new.content, ''));
    new.blocks := new_blocks;
    new_totals := public.calculate_diary_totals(new_blocks);
    new.total_calories := (new_totals->>'total_calories')::integer;
    new.total_protein  := (new_totals->>'total_protein')::decimal;
    new.total_fat      := (new_totals->>'total_fat')::decimal;
    new.total_carbs    := (new_totals->>'total_carbs')::decimal;
    new.total_fiber    := (new_totals->>'total_fiber')::decimal;
    new.total_sugar    := (new_totals->>'total_sugar')::decimal;
    new.total_sodium   := (new_totals->>'total_sodium')::decimal;
    new.ai_analysis_status := 'pending';
    new.ai_analysis_error := null;
  end if;
  return new;
end; $$;

CREATE OR REPLACE FUNCTION "public"."update_diary_entry_content"() RETURNS "trigger"
    LANGUAGE "plpgsql"
AS $$
declare
  new_blocks jsonb;
  new_totals jsonb;
begin
  if old.content is distinct from new.content then
    new_blocks := public.parse_content_into_blocks(new.content);
    new.blocks := new_blocks;
    new_totals := public.calculate_diary_totals(new_blocks);
    new.total_calories := (new_totals->>'total_calories')::integer;
    new.total_protein  := (new_totals->>'total_protein')::decimal;
    new.total_fat      := (new_totals->>'total_fat')::decimal;
    new.total_carbs    := (new_totals->>'total_carbs')::decimal;
    new.total_fiber    := (new_totals->>'total_fiber')::decimal;
    new.total_sugar    := (new_totals->>'total_sugar')::decimal;
    new.total_sodium   := (new_totals->>'total_sodium')::decimal;
    new.ai_analysis_status := 'pending';
    new.ai_analysis_error := null;
  end if;
  return new;
end; $$;

-- Tables
CREATE TABLE IF NOT EXISTS "public"."ai_analysis_cache" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "content_hash" "text" NOT NULL,
    "content" "text" NOT NULL,
    "analysis_result" "jsonb" NOT NULL,
    "confidence" numeric DEFAULT 0.0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "raw_response_text" "text",
    "provider_model" "text",
    "temperature" numeric,
    "prompt_version" "text",
    "parse_ok" boolean DEFAULT false,
    "parse_error_text" "text",
    "attempt" "text",
    "usage_prompt_tokens" integer,
    "usage_completion_tokens" integer,
    "usage_total_tokens" integer,
    CONSTRAINT "ai_analysis_cache_attempt_check" CHECK ((("attempt" = ANY (ARRAY['primary'::"text", 'retry'::"text"])))),
    CONSTRAINT "ai_analysis_cache_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ai_analysis_cache_content_hash_key" UNIQUE ("content_hash")
);

CREATE TABLE IF NOT EXISTS "public"."diary_entries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "date" "date" NOT NULL,
    "content" "text" DEFAULT ''::"text",
    "blocks" "jsonb" DEFAULT '[]'::"jsonb",
    "total_calories" integer DEFAULT 0,
    "total_protein" numeric DEFAULT 0.0,
    "total_fat" numeric DEFAULT 0.0,
    "total_carbs" numeric DEFAULT 0.0,
    "total_fiber" numeric DEFAULT 0.0,
    "total_sugar" numeric DEFAULT 0.0,
    "total_sodium" numeric DEFAULT 0.0,
    "ai_analysis_status" "text" DEFAULT 'pending'::"text",
    "ai_analysis_error" "text",
    "images" "text"[] DEFAULT '{}'::"text"[],
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "diary_entries_ai_analysis_status_check" CHECK ((("ai_analysis_status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'completed'::"text", 'failed'::"text"])))),
    CONSTRAINT "diary_entries_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "diary_entries_user_id_date_key" UNIQUE ("user_id", "date")
);

CREATE TABLE IF NOT EXISTS "public"."popular_food_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "name" "text" NOT NULL,
    "calories" integer NOT NULL,
    "protein" numeric DEFAULT 0.0,
    "fat" numeric DEFAULT 0.0,
    "carbs" numeric DEFAULT 0.0,
    "fiber" numeric DEFAULT 0.0,
    "sugar" numeric DEFAULT 0.0,
    "sodium" numeric DEFAULT 0.0,
    "usage_count" integer DEFAULT 1,
    "last_used" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "popular_food_items_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "popular_food_items_user_id_name_key" UNIQUE ("user_id", "name")
);

CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "updated_at" timestamp with time zone,
    "username" "text",
    "full_name" "text",
    "avatar_url" "text",
    "website" "text",
    CONSTRAINT "username_length" CHECK ((("char_length"("username") >= 3))),
    CONSTRAINT "profiles_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "profiles_username_key" UNIQUE ("username")
);

CREATE TABLE IF NOT EXISTS "public"."user_profiles" (
    "id" "uuid" NOT NULL,
    "email" "text",
    "name" "text",
    "apple_id" "text",
    "daily_calorie_goal" integer DEFAULT 2000,
    "daily_protein_goal" numeric DEFAULT 50.0,
    "daily_fat_goal" numeric DEFAULT 65.0,
    "daily_carb_goal" numeric DEFAULT 250.0,
    "units" "text" DEFAULT 'kcal'::"text",
    "timezone_offset" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "user_profiles_units_check" CHECK ((("units" = ANY (ARRAY['kcal'::"text", 'kJ'::"text"])))),
    CONSTRAINT "user_profiles_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "user_profiles_apple_id_key" UNIQUE ("apple_id")
);

-- Constraints now defined inline in CREATE TABLE statements for PG14 compatibility

-- Indexes
CREATE INDEX IF NOT EXISTS "idx_ai_cache_content_hash" ON "public"."ai_analysis_cache" USING "btree" ("content_hash");
CREATE INDEX IF NOT EXISTS "idx_ai_cache_parse_ok" ON "public"."ai_analysis_cache" USING "btree" ("parse_ok");
CREATE INDEX IF NOT EXISTS "idx_diary_entries_ai_status" ON "public"."diary_entries" USING "btree" ("ai_analysis_status");
CREATE INDEX IF NOT EXISTS "idx_diary_entries_date" ON "public"."diary_entries" USING "btree" ("date");
CREATE INDEX IF NOT EXISTS "idx_diary_entries_user_date" ON "public"."diary_entries" USING "btree" ("user_id", "date");
CREATE INDEX IF NOT EXISTS "idx_popular_food_usage" ON "public"."popular_food_items" USING "btree" ("usage_count" DESC);
CREATE INDEX IF NOT EXISTS "idx_popular_food_user" ON "public"."popular_food_items" USING "btree" ("user_id");

-- Triggers
DROP TRIGGER IF EXISTS "diary_content_before_insert" ON "public"."diary_entries";
DROP TRIGGER IF EXISTS "diary_content_before_update" ON "public"."diary_entries";

CREATE OR REPLACE TRIGGER "diary_content_before_insert" BEFORE INSERT ON "public"."diary_entries" FOR EACH ROW EXECUTE FUNCTION "public"."set_diary_entry_content_derived"();
CREATE OR REPLACE TRIGGER "diary_content_before_update" BEFORE UPDATE ON "public"."diary_entries" FOR EACH ROW EXECUTE FUNCTION "public"."set_diary_entry_content_derived"();

COMMIT;


