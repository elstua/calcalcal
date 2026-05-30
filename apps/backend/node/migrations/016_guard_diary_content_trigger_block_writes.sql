-- Migration 016: Guard diary content-derived trigger from overwriting app-supplied blocks.
--
-- 001_init.sql creates a BEFORE INSERT OR UPDATE trigger that derives blocks from
-- content whenever content changes. That is safe for legacy content-only writes, but
-- PATCH /api/diary/entries/:id now supplies canonical blocks from the app. On those
-- writes the old trigger reparsed content into fresh generated block IDs, wiping
-- userModified, nutrition, stableId, and image metadata.
--
-- The migration runner replays all SQL files on every deploy, so this file must run
-- after 001_init.sql and replace the function idempotently.

CREATE OR REPLACE FUNCTION "public"."set_diary_entry_content_derived"() RETURNS "trigger"
    LANGUAGE "plpgsql"
AS $$
declare
  new_blocks jsonb;
  new_totals jsonb;
begin
  -- INSERT path: preserve explicitly supplied blocks. Derive blocks only when a
  -- legacy/content-only caller inserts content without a block payload.
  if TG_OP = 'INSERT' then
    if coalesce(new.content, '') <> ''
       and (new.blocks is null or new.blocks = '[]'::jsonb) then
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

  -- UPDATE path: derive blocks only for legacy/content-only updates. If the app
  -- supplied a changed blocks payload in the same UPDATE, NEW.blocks differs from
  -- OLD.blocks; in that case preserve it exactly.
  elsif old.content is distinct from new.content
        and OLD.blocks IS NOT DISTINCT FROM NEW.blocks then
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
