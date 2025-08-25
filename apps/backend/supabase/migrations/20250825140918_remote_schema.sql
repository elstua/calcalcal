drop extension if exists "pg_net";

drop trigger if exists "diary_content_before_insert" on "public"."diary_entries";

drop trigger if exists "diary_content_before_update" on "public"."diary_entries";

drop policy "All users can insert AI cache" on "public"."ai_analysis_cache";

drop policy "All users can read AI cache" on "public"."ai_analysis_cache";

drop policy "Users can delete own entries" on "public"."diary_entries";

drop policy "Users can insert own entries" on "public"."diary_entries";

drop policy "Users can update own entries" on "public"."diary_entries";

drop policy "Users can view own entries" on "public"."diary_entries";

drop policy "Users can delete own food items" on "public"."popular_food_items";

drop policy "Users can insert own food items" on "public"."popular_food_items";

drop policy "Users can update own food items" on "public"."popular_food_items";

drop policy "Users can view own and global food items" on "public"."popular_food_items";

drop policy "Users can insert own profile" on "public"."user_profiles";

drop policy "Users can update own profile" on "public"."user_profiles";

drop policy "Users can view own profile" on "public"."user_profiles";

revoke delete on table "public"."ai_analysis_cache" from "anon";

revoke insert on table "public"."ai_analysis_cache" from "anon";

revoke references on table "public"."ai_analysis_cache" from "anon";

revoke select on table "public"."ai_analysis_cache" from "anon";

revoke trigger on table "public"."ai_analysis_cache" from "anon";

revoke truncate on table "public"."ai_analysis_cache" from "anon";

revoke update on table "public"."ai_analysis_cache" from "anon";

revoke delete on table "public"."ai_analysis_cache" from "authenticated";

revoke insert on table "public"."ai_analysis_cache" from "authenticated";

revoke references on table "public"."ai_analysis_cache" from "authenticated";

revoke select on table "public"."ai_analysis_cache" from "authenticated";

revoke trigger on table "public"."ai_analysis_cache" from "authenticated";

revoke truncate on table "public"."ai_analysis_cache" from "authenticated";

revoke update on table "public"."ai_analysis_cache" from "authenticated";

revoke delete on table "public"."ai_analysis_cache" from "service_role";

revoke insert on table "public"."ai_analysis_cache" from "service_role";

revoke references on table "public"."ai_analysis_cache" from "service_role";

revoke select on table "public"."ai_analysis_cache" from "service_role";

revoke trigger on table "public"."ai_analysis_cache" from "service_role";

revoke truncate on table "public"."ai_analysis_cache" from "service_role";

revoke update on table "public"."ai_analysis_cache" from "service_role";

revoke delete on table "public"."diary_entries" from "anon";

revoke insert on table "public"."diary_entries" from "anon";

revoke references on table "public"."diary_entries" from "anon";

revoke select on table "public"."diary_entries" from "anon";

revoke trigger on table "public"."diary_entries" from "anon";

revoke truncate on table "public"."diary_entries" from "anon";

revoke update on table "public"."diary_entries" from "anon";

revoke delete on table "public"."diary_entries" from "authenticated";

revoke insert on table "public"."diary_entries" from "authenticated";

revoke references on table "public"."diary_entries" from "authenticated";

revoke select on table "public"."diary_entries" from "authenticated";

revoke trigger on table "public"."diary_entries" from "authenticated";

revoke truncate on table "public"."diary_entries" from "authenticated";

revoke update on table "public"."diary_entries" from "authenticated";

revoke delete on table "public"."diary_entries" from "service_role";

revoke insert on table "public"."diary_entries" from "service_role";

revoke references on table "public"."diary_entries" from "service_role";

revoke select on table "public"."diary_entries" from "service_role";

revoke trigger on table "public"."diary_entries" from "service_role";

revoke truncate on table "public"."diary_entries" from "service_role";

revoke update on table "public"."diary_entries" from "service_role";

revoke delete on table "public"."popular_food_items" from "anon";

revoke insert on table "public"."popular_food_items" from "anon";

revoke references on table "public"."popular_food_items" from "anon";

revoke select on table "public"."popular_food_items" from "anon";

revoke trigger on table "public"."popular_food_items" from "anon";

revoke truncate on table "public"."popular_food_items" from "anon";

revoke update on table "public"."popular_food_items" from "anon";

revoke delete on table "public"."popular_food_items" from "authenticated";

revoke insert on table "public"."popular_food_items" from "authenticated";

revoke references on table "public"."popular_food_items" from "authenticated";

revoke select on table "public"."popular_food_items" from "authenticated";

revoke trigger on table "public"."popular_food_items" from "authenticated";

revoke truncate on table "public"."popular_food_items" from "authenticated";

revoke update on table "public"."popular_food_items" from "authenticated";

revoke delete on table "public"."popular_food_items" from "service_role";

revoke insert on table "public"."popular_food_items" from "service_role";

revoke references on table "public"."popular_food_items" from "service_role";

revoke select on table "public"."popular_food_items" from "service_role";

revoke trigger on table "public"."popular_food_items" from "service_role";

revoke truncate on table "public"."popular_food_items" from "service_role";

revoke update on table "public"."popular_food_items" from "service_role";

revoke delete on table "public"."user_profiles" from "anon";

revoke insert on table "public"."user_profiles" from "anon";

revoke references on table "public"."user_profiles" from "anon";

revoke select on table "public"."user_profiles" from "anon";

revoke trigger on table "public"."user_profiles" from "anon";

revoke truncate on table "public"."user_profiles" from "anon";

revoke update on table "public"."user_profiles" from "anon";

revoke delete on table "public"."user_profiles" from "authenticated";

revoke insert on table "public"."user_profiles" from "authenticated";

revoke references on table "public"."user_profiles" from "authenticated";

revoke select on table "public"."user_profiles" from "authenticated";

revoke trigger on table "public"."user_profiles" from "authenticated";

revoke truncate on table "public"."user_profiles" from "authenticated";

revoke update on table "public"."user_profiles" from "authenticated";

revoke delete on table "public"."user_profiles" from "service_role";

revoke insert on table "public"."user_profiles" from "service_role";

revoke references on table "public"."user_profiles" from "service_role";

revoke select on table "public"."user_profiles" from "service_role";

revoke trigger on table "public"."user_profiles" from "service_role";

revoke truncate on table "public"."user_profiles" from "service_role";

revoke update on table "public"."user_profiles" from "service_role";

alter table "public"."ai_analysis_cache" drop constraint "ai_analysis_cache_attempt_check";

alter table "public"."ai_analysis_cache" drop constraint "ai_analysis_cache_content_hash_key";

alter table "public"."diary_entries" drop constraint "diary_entries_ai_analysis_status_check";

alter table "public"."diary_entries" drop constraint "diary_entries_user_id_date_key";

alter table "public"."diary_entries" drop constraint "diary_entries_user_id_fkey";

alter table "public"."popular_food_items" drop constraint "popular_food_items_user_id_fkey";

alter table "public"."popular_food_items" drop constraint "popular_food_items_user_id_name_key";

alter table "public"."user_profiles" drop constraint "user_profiles_apple_id_key";

alter table "public"."user_profiles" drop constraint "user_profiles_id_fkey";

alter table "public"."user_profiles" drop constraint "user_profiles_units_check";

drop function if exists "public"."calculate_diary_totals"(blocks_json jsonb);

drop function if exists "public"."parse_content_into_blocks"(content_text text);

drop function if exists "public"."set_diary_entry_content_derived"();

drop function if exists "public"."update_diary_entry_content"();

alter table "public"."ai_analysis_cache" drop constraint "ai_analysis_cache_pkey";

alter table "public"."diary_entries" drop constraint "diary_entries_pkey";

alter table "public"."popular_food_items" drop constraint "popular_food_items_pkey";

alter table "public"."user_profiles" drop constraint "user_profiles_pkey";

drop index if exists "public"."ai_analysis_cache_content_hash_key";

drop index if exists "public"."ai_analysis_cache_pkey";

drop index if exists "public"."diary_entries_pkey";

drop index if exists "public"."diary_entries_user_id_date_key";

drop index if exists "public"."idx_ai_cache_content_hash";

drop index if exists "public"."idx_ai_cache_parse_ok";

drop index if exists "public"."idx_diary_entries_ai_status";

drop index if exists "public"."idx_diary_entries_date";

drop index if exists "public"."idx_diary_entries_user_date";

drop index if exists "public"."idx_popular_food_usage";

drop index if exists "public"."idx_popular_food_user";

drop index if exists "public"."popular_food_items_pkey";

drop index if exists "public"."popular_food_items_user_id_name_key";

drop index if exists "public"."user_profiles_apple_id_key";

drop index if exists "public"."user_profiles_pkey";

drop table "public"."ai_analysis_cache";

drop table "public"."diary_entries";

drop table "public"."popular_food_items";

drop table "public"."user_profiles";


  create table "public"."profiles" (
    "id" uuid not null,
    "updated_at" timestamp with time zone,
    "username" text,
    "full_name" text,
    "avatar_url" text,
    "website" text
      );


alter table "public"."profiles" enable row level security;

CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id);

CREATE UNIQUE INDEX profiles_username_key ON public.profiles USING btree (username);

alter table "public"."profiles" add constraint "profiles_pkey" PRIMARY KEY using index "profiles_pkey";

alter table "public"."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."profiles" validate constraint "profiles_id_fkey";

alter table "public"."profiles" add constraint "profiles_username_key" UNIQUE using index "profiles_username_key";

alter table "public"."profiles" add constraint "username_length" CHECK ((char_length(username) >= 3)) not valid;

alter table "public"."profiles" validate constraint "username_length";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$function$
;

grant delete on table "public"."profiles" to "anon";

grant insert on table "public"."profiles" to "anon";

grant references on table "public"."profiles" to "anon";

grant select on table "public"."profiles" to "anon";

grant trigger on table "public"."profiles" to "anon";

grant truncate on table "public"."profiles" to "anon";

grant update on table "public"."profiles" to "anon";

grant delete on table "public"."profiles" to "authenticated";

grant insert on table "public"."profiles" to "authenticated";

grant references on table "public"."profiles" to "authenticated";

grant select on table "public"."profiles" to "authenticated";

grant trigger on table "public"."profiles" to "authenticated";

grant truncate on table "public"."profiles" to "authenticated";

grant update on table "public"."profiles" to "authenticated";

grant delete on table "public"."profiles" to "service_role";

grant insert on table "public"."profiles" to "service_role";

grant references on table "public"."profiles" to "service_role";

grant select on table "public"."profiles" to "service_role";

grant trigger on table "public"."profiles" to "service_role";

grant truncate on table "public"."profiles" to "service_role";

grant update on table "public"."profiles" to "service_role";


  create policy "Public profiles are viewable by everyone."
  on "public"."profiles"
  as permissive
  for select
  to public
using (true);



  create policy "Users can insert their own profile."
  on "public"."profiles"
  as permissive
  for insert
  to public
with check ((( SELECT auth.uid() AS uid) = id));



  create policy "Users can update own profile."
  on "public"."profiles"
  as permissive
  for update
  to public
using ((( SELECT auth.uid() AS uid) = id));



