-- Migration 017: Smart cache columns for nutrition intelligence pipeline
-- Adds normalized content, multilingual variant tracking, hit counting,
-- per-unit storage, and fuzzy matching support via pg_trgm.

-- Enable pg_trgm for fuzzy string matching (similarity function)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Add smart cache columns to ai_analysis_cache
ALTER TABLE ai_analysis_cache ADD COLUMN IF NOT EXISTS normalized_content TEXT;
ALTER TABLE ai_analysis_cache ADD COLUMN IF NOT EXISTS original_variants TEXT[] DEFAULT '{}';
ALTER TABLE ai_analysis_cache ADD COLUMN IF NOT EXISTS hit_count INT DEFAULT 0;
ALTER TABLE ai_analysis_cache ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'llm';
ALTER TABLE ai_analysis_cache ADD COLUMN IF NOT EXISTS unit_description TEXT;
ALTER TABLE ai_analysis_cache ADD COLUMN IF NOT EXISTS unit_calories NUMERIC;
ALTER TABLE ai_analysis_cache ADD COLUMN IF NOT EXISTS normalized_hash TEXT;

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_cache_normalized ON ai_analysis_cache(normalized_content);
CREATE INDEX IF NOT EXISTS idx_cache_normalized_hash ON ai_analysis_cache(normalized_hash);
CREATE INDEX IF NOT EXISTS idx_cache_hit_count ON ai_analysis_cache(hit_count DESC);
