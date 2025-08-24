-- Add debug/transparency fields to AI cache for troubleshooting parsing and provider issues
alter table if exists public.ai_analysis_cache
  add column if not exists raw_response_text text,
  add column if not exists provider_model text,
  add column if not exists temperature numeric,
  add column if not exists prompt_version text,
  add column if not exists parse_ok boolean default false,
  add column if not exists parse_error_text text,
  add column if not exists attempt text check (attempt in ('primary','retry')),
  add column if not exists usage_prompt_tokens integer,
  add column if not exists usage_completion_tokens integer,
  add column if not exists usage_total_tokens integer;

create index if not exists idx_ai_cache_parse_ok on public.ai_analysis_cache(parse_ok);



