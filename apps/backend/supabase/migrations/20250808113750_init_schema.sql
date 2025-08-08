-- Initial schema from Docs/backend-specification.md
create extension if not exists pgcrypto;

-- user_profiles
create table if not exists public.user_profiles (
  id uuid references auth.users(id) primary key,
  email text,
  name text,
  apple_id text unique,
  daily_calorie_goal integer default 2000,
  daily_protein_goal decimal default 50.0,
  daily_fat_goal decimal default 65.0,
  daily_carb_goal decimal default 250.0,
  units text default 'kcal' check (units in ('kcal','kJ')),
  timezone_offset integer default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.user_profiles enable row level security;
drop policy if exists "Users can view own profile" on public.user_profiles;
drop policy if exists "Users can update own profile" on public.user_profiles;
drop policy if exists "Users can insert own profile" on public.user_profiles;
create policy "Users can view own profile" on public.user_profiles for select using (auth.uid() = id);
create policy "Users can update own profile" on public.user_profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on public.user_profiles for insert with check (auth.uid() = id);

-- diary_entries
create table if not exists public.diary_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) not null,
  date date not null,
  content text default '',
  blocks jsonb default '[]'::jsonb,
  total_calories integer default 0,
  total_protein decimal default 0.0,
  total_fat decimal default 0.0,
  total_carbs decimal default 0.0,
  total_fiber decimal default 0.0,
  total_sugar decimal default 0.0,
  total_sodium decimal default 0.0,
  ai_analysis_status text default 'pending' check (ai_analysis_status in ('pending','processing','completed','failed')),
  ai_analysis_error text,
  images text[] default '{}',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id, date)
);

create index if not exists idx_diary_entries_user_date on public.diary_entries(user_id, date);
create index if not exists idx_diary_entries_date on public.diary_entries(date);
create index if not exists idx_diary_entries_ai_status on public.diary_entries(ai_analysis_status);

alter table public.diary_entries enable row level security;
drop policy if exists "Users can view own entries" on public.diary_entries;
drop policy if exists "Users can insert own entries" on public.diary_entries;
drop policy if exists "Users can update own entries" on public.diary_entries;
drop policy if exists "Users can delete own entries" on public.diary_entries;
create policy "Users can view own entries" on public.diary_entries for select using (auth.uid() = user_id);
create policy "Users can insert own entries" on public.diary_entries for insert with check (auth.uid() = user_id);
create policy "Users can update own entries" on public.diary_entries for update using (auth.uid() = user_id);
create policy "Users can delete own entries" on public.diary_entries for delete using (auth.uid() = user_id);

-- popular_food_items
create table if not exists public.popular_food_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),
  name text not null,
  calories integer not null,
  protein decimal default 0.0,
  fat decimal default 0.0,
  carbs decimal default 0.0,
  fiber decimal default 0.0,
  sugar decimal default 0.0,
  sodium decimal default 0.0,
  usage_count integer default 1,
  last_used timestamptz default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id, name)
);

create index if not exists idx_popular_food_user on public.popular_food_items(user_id);
create index if not exists idx_popular_food_usage on public.popular_food_items(usage_count desc);

alter table public.popular_food_items enable row level security;
drop policy if exists "Users can view own and global food items" on public.popular_food_items;
drop policy if exists "Users can insert own food items" on public.popular_food_items;
drop policy if exists "Users can update own food items" on public.popular_food_items;
drop policy if exists "Users can delete own food items" on public.popular_food_items;
create policy "Users can view own and global food items" on public.popular_food_items for select using (user_id = auth.uid() or user_id is null);
create policy "Users can insert own food items" on public.popular_food_items for insert with check (user_id = auth.uid());
create policy "Users can update own food items" on public.popular_food_items for update using (user_id = auth.uid());
create policy "Users can delete own food items" on public.popular_food_items for delete using (user_id = auth.uid());

-- ai_analysis_cache
create table if not exists public.ai_analysis_cache (
  id uuid primary key default gen_random_uuid(),
  content_hash text unique not null,
  content text not null,
  analysis_result jsonb not null,
  confidence decimal default 0.0,
  created_at timestamptz default now()
);

create index if not exists idx_ai_cache_content_hash on public.ai_analysis_cache(content_hash);

alter table public.ai_analysis_cache enable row level security;
drop policy if exists "All users can read AI cache" on public.ai_analysis_cache;
drop policy if exists "All users can insert AI cache" on public.ai_analysis_cache;
create policy "All users can read AI cache" on public.ai_analysis_cache for select using (auth.role() = 'authenticated');
create policy "All users can insert AI cache" on public.ai_analysis_cache for insert with check (auth.role() = 'authenticated');

-- functions
create or replace function public.parse_content_into_blocks(content_text text)
returns jsonb language plpgsql as $$
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

create or replace function public.calculate_diary_totals(blocks_json jsonb)
returns jsonb language plpgsql as $$
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

create or replace function public.update_diary_entry_content()
returns trigger language plpgsql as $$
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

drop trigger if exists update_diary_content_trigger on public.diary_entries;
create trigger update_diary_content_trigger
  before update on public.diary_entries
  for each row execute function public.update_diary_entry_content();

-- storage bucket for images (create via direct insert to avoid version-specific function signature)
insert into storage.buckets (id, name, public)
select 'images', 'images', true
where not exists (select 1 from storage.buckets where id = 'images');

