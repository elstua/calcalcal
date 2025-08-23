-- Add a unified trigger function that derives blocks and totals from content
-- on both INSERT and UPDATE. Then attach it as BEFORE INSERT and BEFORE UPDATE.

create or replace function public.set_diary_entry_content_derived()
returns trigger language plpgsql as $$
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

-- Recreate triggers to use the unified function
drop trigger if exists update_diary_content_trigger on public.diary_entries;
drop trigger if exists diary_content_before_update on public.diary_entries;
drop trigger if exists diary_content_before_insert on public.diary_entries;

create trigger diary_content_before_update
  before update on public.diary_entries
  for each row execute function public.set_diary_entry_content_derived();

create trigger diary_content_before_insert
  before insert on public.diary_entries
  for each row execute function public.set_diary_entry_content_derived();


