

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



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


ALTER FUNCTION "public"."calculate_diary_totals"("blocks_json" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


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


ALTER FUNCTION "public"."parse_content_into_blocks"("content_text" "text") OWNER TO "postgres";


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


ALTER FUNCTION "public"."set_diary_entry_content_derived"() OWNER TO "postgres";


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


ALTER FUNCTION "public"."update_diary_entry_content"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


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
    CONSTRAINT "ai_analysis_cache_attempt_check" CHECK (("attempt" = ANY (ARRAY['primary'::"text", 'retry'::"text"])))
);


ALTER TABLE "public"."ai_analysis_cache" OWNER TO "postgres";


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
    CONSTRAINT "diary_entries_ai_analysis_status_check" CHECK (("ai_analysis_status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'completed'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."diary_entries" OWNER TO "postgres";


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
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."popular_food_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "updated_at" timestamp with time zone,
    "username" "text",
    "full_name" "text",
    "avatar_url" "text",
    "website" "text",
    CONSTRAINT "username_length" CHECK (("char_length"("username") >= 3))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


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
    CONSTRAINT "user_profiles_units_check" CHECK (("units" = ANY (ARRAY['kcal'::"text", 'kJ'::"text"])))
);


ALTER TABLE "public"."user_profiles" OWNER TO "postgres";


ALTER TABLE ONLY "public"."ai_analysis_cache"
    ADD CONSTRAINT "ai_analysis_cache_content_hash_key" UNIQUE ("content_hash");



ALTER TABLE ONLY "public"."ai_analysis_cache"
    ADD CONSTRAINT "ai_analysis_cache_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."diary_entries"
    ADD CONSTRAINT "diary_entries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."diary_entries"
    ADD CONSTRAINT "diary_entries_user_id_date_key" UNIQUE ("user_id", "date");



ALTER TABLE ONLY "public"."popular_food_items"
    ADD CONSTRAINT "popular_food_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."popular_food_items"
    ADD CONSTRAINT "popular_food_items_user_id_name_key" UNIQUE ("user_id", "name");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_username_key" UNIQUE ("username");



ALTER TABLE ONLY "public"."user_profiles"
    ADD CONSTRAINT "user_profiles_apple_id_key" UNIQUE ("apple_id");



ALTER TABLE ONLY "public"."user_profiles"
    ADD CONSTRAINT "user_profiles_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_ai_cache_content_hash" ON "public"."ai_analysis_cache" USING "btree" ("content_hash");



CREATE INDEX "idx_ai_cache_parse_ok" ON "public"."ai_analysis_cache" USING "btree" ("parse_ok");



CREATE INDEX "idx_diary_entries_ai_status" ON "public"."diary_entries" USING "btree" ("ai_analysis_status");



CREATE INDEX "idx_diary_entries_date" ON "public"."diary_entries" USING "btree" ("date");



CREATE INDEX "idx_diary_entries_user_date" ON "public"."diary_entries" USING "btree" ("user_id", "date");



CREATE INDEX "idx_popular_food_usage" ON "public"."popular_food_items" USING "btree" ("usage_count" DESC);



CREATE INDEX "idx_popular_food_user" ON "public"."popular_food_items" USING "btree" ("user_id");



CREATE OR REPLACE TRIGGER "diary_content_before_insert" BEFORE INSERT ON "public"."diary_entries" FOR EACH ROW EXECUTE FUNCTION "public"."set_diary_entry_content_derived"();



CREATE OR REPLACE TRIGGER "diary_content_before_update" BEFORE UPDATE ON "public"."diary_entries" FOR EACH ROW EXECUTE FUNCTION "public"."set_diary_entry_content_derived"();



ALTER TABLE ONLY "public"."diary_entries"
    ADD CONSTRAINT "diary_entries_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."popular_food_items"
    ADD CONSTRAINT "popular_food_items_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_profiles"
    ADD CONSTRAINT "user_profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id");



CREATE POLICY "All users can insert AI cache" ON "public"."ai_analysis_cache" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "All users can read AI cache" ON "public"."ai_analysis_cache" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Public profiles are viewable by everyone." ON "public"."profiles" FOR SELECT USING (true);



CREATE POLICY "Users can delete own entries" ON "public"."diary_entries" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete own food items" ON "public"."popular_food_items" FOR DELETE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can insert own entries" ON "public"."diary_entries" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own food items" ON "public"."popular_food_items" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can insert own profile" ON "public"."user_profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Users can insert their own profile." ON "public"."profiles" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Users can update own entries" ON "public"."diary_entries" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own food items" ON "public"."popular_food_items" FOR UPDATE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can update own profile" ON "public"."user_profiles" FOR UPDATE USING (("auth"."uid"() = "id"));



CREATE POLICY "Users can update own profile." ON "public"."profiles" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Users can view own and global food items" ON "public"."popular_food_items" FOR SELECT USING ((("user_id" = "auth"."uid"()) OR ("user_id" IS NULL)));



CREATE POLICY "Users can view own entries" ON "public"."diary_entries" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own profile" ON "public"."user_profiles" FOR SELECT USING (("auth"."uid"() = "id"));



ALTER TABLE "public"."ai_analysis_cache" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."diary_entries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."popular_food_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_profiles" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_diary_totals"("blocks_json" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_diary_totals"("blocks_json" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_diary_totals"("blocks_json" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."parse_content_into_blocks"("content_text" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."parse_content_into_blocks"("content_text" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."parse_content_into_blocks"("content_text" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_diary_entry_content_derived"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_diary_entry_content_derived"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_diary_entry_content_derived"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_diary_entry_content"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_diary_entry_content"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_diary_entry_content"() TO "service_role";



GRANT ALL ON TABLE "public"."ai_analysis_cache" TO "anon";
GRANT ALL ON TABLE "public"."ai_analysis_cache" TO "authenticated";
GRANT ALL ON TABLE "public"."ai_analysis_cache" TO "service_role";



GRANT ALL ON TABLE "public"."diary_entries" TO "anon";
GRANT ALL ON TABLE "public"."diary_entries" TO "authenticated";
GRANT ALL ON TABLE "public"."diary_entries" TO "service_role";



GRANT ALL ON TABLE "public"."popular_food_items" TO "anon";
GRANT ALL ON TABLE "public"."popular_food_items" TO "authenticated";
GRANT ALL ON TABLE "public"."popular_food_items" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."user_profiles" TO "anon";
GRANT ALL ON TABLE "public"."user_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."user_profiles" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";






RESET ALL;
