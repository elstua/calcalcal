/**
 * Backfill smart cache columns for existing ai_analysis_cache rows.
 *
 * What it does:
 * 1. For every existing cache row: compute normalized_content, normalized_hash,
 *    extract unit nutrition (per-unit calories), store source='llm'.
 * 2. Aggregate hit_counts from actual diary block usage across all entries.
 * 3. Populate original_variants with distinct raw forms from diary blocks.
 *
 * Idempotent — safe to run multiple times (uses COALESCE / WHERE guards).
 *
 * Run: npm run backfill:smart-cache
 *   or: npx ts-node src/scripts/backfillSmartCache.ts
 */

import Database from "../services/database";
import {
  normalize,
  extractQuantity,
  findCanonicalForm,
  hashNormalized,
} from "../services/ai/normalization";

async function main() {
  console.log("=== Smart Cache Backfill ===\n");

  // Step 1: Compute normalized content + unit nutrition for existing cache rows
  console.log("Step 1: Normalizing existing cache entries...");
  const cacheRows = await Database.query<{
    id: number;
    content: string;
    content_hash: string;
    analysis_result: any;
  }>(`SELECT id, content, content_hash, analysis_result FROM ai_analysis_cache`);

  console.log(`Found ${cacheRows.rows.length} existing cache entries.\n`);

  let normalized = 0;
  for (const row of cacheRows.rows) {
    const content = (row.content || "").toString().trim();
    if (!content) continue;

    const normalizedContent = normalize(content);
    const qty = extractQuantity(content);
    const canonical = findCanonicalForm(normalizedContent) || normalizedContent;
    const nHash = hashNormalized(canonical);

    const analysisResult = row.analysis_result || {};
    const totalCalories = Number(analysisResult.calories || 0);

    // Compute per-unit calories: total / quantity
    const unitCalories =
      qty.quantity > 0 ? Math.round(totalCalories / qty.quantity) : totalCalories;

    // Determine unit description from analysis result
    const unitDescription =
      analysisResult.metric_description ||
      analysisResult.description ||
      (qty.unit !== "piece" ? `1 ${qty.unit}` : `1 ${qty.item}`);

    await Database.query(
      `UPDATE ai_analysis_cache
       SET normalized_content = COALESCE(normalized_content, $2),
           normalized_hash    = COALESCE(normalized_hash, $3),
           unit_calories      = COALESCE(unit_calories, $4),
           unit_description   = COALESCE(unit_description, $5),
           source             = COALESCE(source, 'llm'),
           hit_count          = COALESCE(hit_count, 0)
       WHERE id = $1
         AND (normalized_content IS NULL OR normalized_hash IS NULL)`,
      [row.id, canonical, nHash, unitCalories, unitDescription]
    );
    normalized++;
  }

  console.log(`Normalized ${normalized} entries.\n`);

  // Step 2: Aggregate hit counts from diary blocks
  console.log("Step 2: Computing hit counts from diary usage...");

  const diaryFoods = await Database.query<{
    food: string;
    times_logged: number;
  }>(`
    SELECT LOWER(TRIM(b->>'content')) AS food, COUNT(*) AS times_logged
    FROM diary_entries,
      LATERAL jsonb_array_elements(blocks) AS b
    WHERE b->>'content' IS NOT NULL
      AND b->>'content' != ''
      AND b->>'content' != 'write what you ate today'
    GROUP BY LOWER(TRIM(b->>'content'))
    ORDER BY times_logged DESC
  `);

  console.log(`Found ${diaryFoods.rows.length} unique food strings in diary.\n`);

  let hitsUpdated = 0;
  let totalSavedHits = 0;

  for (const food of diaryFoods.rows) {
    const content = food.food;
    if (!content) continue;

    const normalizedContent = normalize(content);
    const canonical = findCanonicalForm(normalizedContent) || normalizedContent;
    const nHash = hashNormalized(canonical);

    // Try to match against cache rows (exact normalized hash match)
    const match = await Database.query<{ id: number }>(
      `SELECT id FROM ai_analysis_cache
       WHERE normalized_hash = $1
       LIMIT 1`,
      [nHash]
    );

    if (match.rows.length > 0) {
      const cacheId = match.rows[0].id;
      await Database.query(
        `UPDATE ai_analysis_cache
         SET hit_count = hit_count + $1
         WHERE id = $2`,
        [food.times_logged, cacheId]
      );
      hitsUpdated++;
      totalSavedHits += food.times_logged;
    }
  }

  console.log(
    `Matched ${hitsUpdated} diary foods to cache entries.`
  );
  console.log(
    `Total hit count added: ${totalSavedHits} (these are LLM calls that WOULD have been needed without caching)\n`
  );

  // Step 3: Add original_variants from diary blocks
  console.log("Step 3: Collecting original text variants...");

  const variants = await Database.query<{
    normalized: string;
    variants: string[];
  }>(`
    WITH food_texts AS (
      SELECT
        LOWER(TRIM(b->>'content')) AS normalized_lower,
        TRIM(b->>'content') AS original_text
      FROM diary_entries,
        LATERAL jsonb_array_elements(blocks) AS b
      WHERE b->>'content' IS NOT NULL
        AND b->>'content' != ''
        AND b->>'content' != 'write what you ate today'
    )
    SELECT normalized_lower AS normalized,
           ARRAY_AGG(DISTINCT original_text) AS variants
    FROM food_texts
    GROUP BY normalized_lower
  `);

  let variantsUpdated = 0;
  for (const v of variants.rows) {
    const nHash = hashNormalized(
      findCanonicalForm(v.normalized) || v.normalized
    );

    const result = await Database.query(
      `UPDATE ai_analysis_cache
       SET original_variants = $2
       WHERE normalized_hash = $1
         AND (original_variants IS NULL OR original_variants = '{}')`,
      [nHash, v.variants]
    );
    variantsUpdated += (result as any).rowCount || 0;
  }

  console.log(`Updated variants for ${variantsUpdated} cache entries.\n`);

  // Summary
  console.log("=== Backfill Complete ===");
  const summary = await Database.query<{
    total: number;
    with_normalized: number;
    with_hits: number;
    total_hits: number;
  }>(`
    SELECT
      COUNT(*) AS total,
      COUNT(normalized_hash) AS with_normalized,
      COUNT(*) FILTER (WHERE hit_count > 0) AS with_hits,
      COALESCE(SUM(hit_count), 0) AS total_hits
    FROM ai_analysis_cache
  `);

  const s = summary.rows[0];
  console.log(`  Total cache entries:     ${s.total}`);
  console.log(`  With normalized data:    ${s.with_normalized}`);
  console.log(`  Entries with hits > 0:   ${s.with_hits}`);
  console.log(`  Total accumulated hits:  ${s.total_hits}`);
  console.log(
    `\n  Estimated cost saved:    ~$${(s.total_hits * 0.002).toFixed(2)} (at ~0.2¢ per Gemini Flash call)`
  );

  console.log("\nDone.");
  process.exit(0);
}

main().catch((err) => {
  console.error("Backfill failed:", err);
  process.exit(1);
});
