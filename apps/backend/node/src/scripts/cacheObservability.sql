-- ============================================================
-- Nutrition Intelligence Pipeline — Observability Queries
-- ============================================================
-- Run any of these against production DB for pipeline health.
-- Usage:
--   ssh root@157.180.20.251 "docker exec calcalcal-db psql -U calcalcal -d calcalcal_production -f /path/to/this-file.sql"
-- Or selectively copy individual queries.
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- 1. OVERALL HEALTH DASHBOARD
-- ──────────────────────────────────────────────────────────

\echo '=== Pipeline Overview ==='
SELECT
  COUNT(*) AS total_cached_items,
  COUNT(*) FILTER (WHERE normalized_hash IS NOT NULL) AS normalized,
  COUNT(*) FILTER (WHERE hit_count > 0) AS items_with_hits,
  COALESCE(SUM(hit_count), 0) AS total_cache_hits,
  COUNT(*) FILTER (WHERE hit_count = 0) AS items_never_hit,
  ROUND(
    COALESCE(SUM(hit_count), 0)::numeric /
    NULLIF(COUNT(*) FILTER (WHERE hit_count > 0), 0)::numeric, 1
  ) AS avg_hits_per_popular_item
FROM ai_analysis_cache;

-- ──────────────────────────────────────────────────────────
-- 2. CACHE HIT RATE (real-time, from API logs)
--    Parse docker logs for [CacheLookupService] lines
-- ──────────────────────────────────────────────────────────

\echo '=== Source Breakdown ==='
SELECT
  COALESCE(source, 'llm') AS source,
  COUNT(*) AS items,
  COALESCE(SUM(hit_count), 0) AS total_hits,
  ROUND(COALESCE(SUM(hit_count), 0)::numeric / NULLIF(SUM(SUM(hit_count)) OVER(), 0) * 100, 1) AS pct_of_hits
FROM ai_analysis_cache
GROUP BY COALESCE(source, 'llm')
ORDER BY total_hits DESC;

-- ──────────────────────────────────────────────────────────
-- 3. TOP CACHED ITEMS (what users eat most)
-- ──────────────────────────────────────────────────────────

\echo '=== Top 20 Cached Foods by Hit Count ==='
SELECT
  normalized_content AS food,
  hit_count AS hits,
  unit_calories AS kcal_per_unit,
  unit_description AS unit,
  original_variants[1:3] AS sample_variants,
  source
FROM ai_analysis_cache
WHERE normalized_hash IS NOT NULL AND hit_count > 0
ORDER BY hit_count DESC
LIMIT 20;

-- ──────────────────────────────────────────────────────────
-- 4. COST ESTIMATE
-- ──────────────────────────────────────────────────────────

\echo '=== Cost Estimate ==='
SELECT
  COALESCE(SUM(hit_count), 0) AS cache_hits_saved,
  ROUND(COALESCE(SUM(hit_count), 0)::numeric * 0.002, 2) AS estimated_dollars_saved,
  COUNT(*) - COUNT(*) FILTER (WHERE COALESCE(source, 'llm') != 'llm') AS db_sourced_items,
  COUNT(*) FILTER (WHERE COALESCE(source, 'llm') != 'llm') AS non_llm_items
FROM ai_analysis_cache;

-- Gemini Flash pricing (as of mid-2026):
--   Input:  $0.075 / 1M tokens
--   Output: $0.30  / 1M tokens
-- Average nutrition prompt: ~500 input tokens + ~150 output tokens ≈ $0.00008/call
-- Rounding up to $0.002 with overhead for safety.

-- ──────────────────────────────────────────────────────────
-- 5. CACHE MISS CANDIDATES
--    Foods in diary that DON'T have a cache entry yet
--    (these still hit the LLM every time)
-- ──────────────────────────────────────────────────────────

\echo '=== Foods Without Cache (still hit LLM every time) ==='
WITH diary_foods AS (
  SELECT LOWER(TRIM(b->>'content')) AS food, COUNT(*) AS times_logged
  FROM diary_entries,
    LATERAL jsonb_array_elements(blocks) AS b
  WHERE b->>'content' IS NOT NULL
    AND b->>'content' != ''
    AND b->>'content' != 'write what you ate today'
  GROUP BY LOWER(TRIM(b->>'content'))
)
SELECT df.food, df.times_logged
FROM diary_foods df
LEFT JOIN ai_analysis_cache ac
  ON LOWER(TRIM(ac.content)) = df.food
  OR ac.normalized_content = df.food
WHERE ac.content IS NULL
  AND df.times_logged >= 2
ORDER BY df.times_logged DESC
LIMIT 20;

-- ──────────────────────────────────────────────────────────
-- 6. SYNONYM COVERAGE
--    How many diary foods match a known synonym vs don't
-- ──────────────────────────────────────────────────────────

\echo '=== Synonym Resolution Stats ==='
SELECT
  COUNT(*) FILTER (WHERE ac.normalized_hash IS NOT NULL) AS resolved_via_cache,
  COUNT(*) FILTER (WHERE ac.normalized_hash IS NULL) AS no_cache_match,
  COUNT(*) AS total_diary_foods
FROM (
  SELECT DISTINCT LOWER(TRIM(b->>'content')) AS food
  FROM diary_entries,
    LATERAL jsonb_array_elements(blocks) AS b
  WHERE b->>'content' IS NOT NULL
    AND b->>'content' != ''
    AND b->>'content' != 'write what you ate today'
) AS diary_foods
LEFT JOIN ai_analysis_cache ac ON ac.normalized_content = diary_foods.food;
