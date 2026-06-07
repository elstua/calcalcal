import { AIAnalysisCacheModel, AIAnalysisCacheRow } from '../../models/AIAnalysisCache';
import {
  normalize,
  extractQuantity,
  findCanonicalForm,
  hashNormalized,
  normalizeForHash,
  splitIntoSegments,
  ExtractedQuantity,
} from './normalization';

export interface CacheLookupResult {
  /** The original content string the user provided */
  content: string;
  /** Extracted quantity info */
  quantity: number;
  unit: string;
  item: string;
  /** The cached analysis result (per-unit nutrition, or assembled totals for multi-item) */
  analysis_result: any;
  confidence: number;
  /** Whether this was scaled from per-unit values */
  scaled: boolean;
  /** How was the cache hit produced */
  hitType: 'exact' | 'fuzzy' | 'assembled';
  /** Source of the cached data */
  source?: string;
}

/**
 * Scale a per-unit analysis result to the requested quantity.
 * E.g., if unit_calories=78 (1 egg) and user wants "3 eggs", multiply all macros by 3.
 */
function scaleToQuantity(
  cached: AIAnalysisCacheRow,
  qty: ExtractedQuantity
): any {
  const result = cached.analysis_result;
  if (!result) return result;

  const factor = qty.quantity || 1;

  if (cached.unit_calories != null) {
    return {
      calories: Math.round(Number(result.calories) * factor),
      protein: Math.round((Number(result.protein) || 0) * factor * 10) / 10,
      fat: Math.round((Number(result.fat) || 0) * factor * 10) / 10,
      carbs: Math.round((Number(result.carbs) || 0) * factor * 10) / 10,
      fiber: Math.round((Number(result.fiber) || 0) * factor * 10) / 10,
      sugar: Math.round((Number(result.sugar) || 0) * factor * 10) / 10,
      sodium: Math.round((Number(result.sodium) || 0) * factor * 10) / 10,
    };
  }

  return {
    calories: Math.round((Number(result.calories) || 0) * factor),
    protein: Math.round((Number(result.protein) || 0) * factor * 10) / 10,
    fat: Math.round((Number(result.fat) || 0) * factor * 10) / 10,
    carbs: Math.round((Number(result.carbs) || 0) * factor * 10) / 10,
    fiber: Math.round((Number(result.fiber) || 0) * factor * 10) / 10,
    sugar: Math.round((Number(result.sugar) || 0) * factor * 10) / 10,
    sodium: Math.round((Number(result.sodium) || 0) * factor * 10) / 10,
  };
}

/**
 * Length-ratio guard: reject a fuzzy match when the cached entry is much shorter
 * or longer than the query, so a cached "cappuccino" can't match a longer block
 * like "cappuccino and banana" even if similarity > threshold.
 *
 * Allows up to 2× length difference for things like "cap" vs "cappuccino" via
 * canonical synonyms, but keeps it tight enough to prevent cross-contamination.
 */
function lengthRatioOk(queryLen: number, cachedLen: number): boolean {
  if (cachedLen === 0) return false;
  const ratio = queryLen / cachedLen;
  // ratio of 1.5 allows minor variants; anything more (e.g. 2×) is suspect
  return ratio >= 0.67 && ratio <= 1.5;
}

/**
 * Look up a single segment (expected to be one food item) in the cache.
 * Tries exact normalized hash first, then fuzzy with a length-ratio guard.
 * Returns the scaled nutrition or null on miss.
 */
async function lookupSegment(
  segment: string,
  promptVersion: string
): Promise<{ scaled: any; confidence: number; hitType: 'exact' | 'fuzzy' } | null> {
  const normalized = normalize(segment);
  const canonicalBase = normalizeForHash(segment);
  const hash = hashNormalized(canonicalBase);
  const qty = extractQuantity(segment);

  // 1. Exact normalized hash match
  const exact = await AIAnalysisCacheModel.getByNormalizedHash(hash, promptVersion);
  if (exact) {
    const effectiveHash = exact.normalized_hash || hash;
    await AIAnalysisCacheModel.incrementHitCount(effectiveHash);
    await AIAnalysisCacheModel.updateVariants(effectiveHash, segment);
    return {
      scaled: scaleToQuantity(exact, qty),
      confidence: exact.confidence,
      hitType: 'exact',
    };
  }

  // 2. Fuzzy match via pg_trgm — only when the cached entry is a similar length.
  // This prevents a short cached "cappuccino" from matching a long multi-item segment.
  try {
    const fuzzy = await AIAnalysisCacheModel.getByFuzzyMatch(normalized, 0.3, promptVersion);
    if (fuzzy && fuzzy.normalized_hash) {
      const cachedLen = (fuzzy.normalized_content || '').length;
      if (lengthRatioOk(normalized.length, cachedLen)) {
        await AIAnalysisCacheModel.incrementHitCount(fuzzy.normalized_hash);
        await AIAnalysisCacheModel.updateVariants(fuzzy.normalized_hash, segment);
        return {
          scaled: scaleToQuantity(fuzzy, qty),
          confidence: fuzzy.confidence,
          hitType: 'fuzzy',
        };
      }
    }
  } catch {
    // pg_trgm not available; fall through
  }

  return null;
}

export class CacheLookupService {
  /**
   * Perform a smart cache lookup for food content.
   *
   * For single-item blocks: tries exact normalized match then length-guarded fuzzy.
   * For multi-item blocks (split on "and", "+", ",", "&", newlines):
   *   - Looks up each segment individually.
   *   - If every segment hits, assembles a combined result with summed totals and
   *     an items[] array (so the caller gets proper per-item breakdown).
   *   - If any segment misses, returns null so the LLM handles the full block.
   *
   * Returns null on any miss.
   */
  static async lookup(content: string, promptVersion: string = 'v1'): Promise<CacheLookupResult | null> {
    const segments = splitIntoSegments(content);

    if (segments.length === 1) {
      // Single-item fast path (original behaviour)
      return CacheLookupService._lookupSingle(content, promptVersion);
    }

    // Multi-item path: look up every segment individually
    const hits = await Promise.all(
      segments.map(seg => lookupSegment(seg, promptVersion))
    );

    if (hits.some(h => h === null)) {
      // At least one segment is not cached — fall through to LLM
      return null;
    }

    // All segments hit — assemble combined result
    const items = segments.map((seg, i) => {
      const hit = hits[i]!;
      const qty = extractQuantity(seg);
      const canonical = findCanonicalForm(normalize(seg));
      return {
        name: canonical || normalize(seg),
        source_text: seg,
        quantity: qty.quantity,
        calories: hit.scaled.calories ?? 0,
        protein: hit.scaled.protein ?? 0,
        fat: hit.scaled.fat ?? 0,
        carbs: hit.scaled.carbs ?? 0,
        fiber: hit.scaled.fiber ?? 0,
        sugar: hit.scaled.sugar ?? 0,
        sodium: hit.scaled.sodium ?? 0,
      };
    });

    const totalCalories = items.reduce((s, it) => s + (it.calories || 0), 0);
    const totalProtein  = items.reduce((s, it) => s + (it.protein  || 0), 0);
    const totalFat      = items.reduce((s, it) => s + (it.fat      || 0), 0);
    const totalCarbs    = items.reduce((s, it) => s + (it.carbs    || 0), 0);
    const totalFiber    = items.reduce((s, it) => s + (it.fiber    || 0), 0);
    const totalSugar    = items.reduce((s, it) => s + (it.sugar    || 0), 0);
    const totalSodium   = items.reduce((s, it) => s + (it.sodium   || 0), 0);

    const minConfidence = Math.min(...hits.map(h => h!.confidence));

    return {
      content,
      quantity: 1,
      unit: 'piece',
      item: content,
      analysis_result: {
        calories: Math.round(totalCalories),
        protein: Math.round(totalProtein * 10) / 10,
        fat: Math.round(totalFat * 10) / 10,
        carbs: Math.round(totalCarbs * 10) / 10,
        fiber: Math.round(totalFiber * 10) / 10,
        sugar: Math.round(totalSugar * 10) / 10,
        sodium: Math.round(totalSodium * 10) / 10,
        items,
      },
      confidence: minConfidence,
      scaled: false,
      hitType: 'assembled',
      source: 'cache-assembly',
    };
  }

  /** Single-item lookup (original behaviour, now also used as a building block). */
  private static async _lookupSingle(
    content: string,
    promptVersion: string
  ): Promise<CacheLookupResult | null> {
    const normalized = normalize(content);
    const canonicalBase = normalizeForHash(content);
    const hash = hashNormalized(canonicalBase);
    const qty = extractQuantity(content);

    // 1. Exact normalized hash match
    const exact = await AIAnalysisCacheModel.getByNormalizedHash(hash, promptVersion);
    if (exact) {
      const effectiveHash = exact.normalized_hash || hash;
      await AIAnalysisCacheModel.incrementHitCount(effectiveHash);
      await AIAnalysisCacheModel.updateVariants(effectiveHash, content);
      const scaledResult = scaleToQuantity(exact, qty);
      return {
        content,
        quantity: qty.quantity,
        unit: qty.unit,
        item: qty.item,
        analysis_result: scaledResult,
        confidence: exact.confidence,
        scaled: qty.quantity !== 1,
        hitType: 'exact',
        source: exact.source,
      };
    }

    // 2. Fuzzy match via pg_trgm — with length-ratio guard
    try {
      const fuzzy = await AIAnalysisCacheModel.getByFuzzyMatch(normalized, 0.3, promptVersion);
      if (fuzzy && fuzzy.normalized_hash) {
        const cachedLen = (fuzzy.normalized_content || '').length;
        if (lengthRatioOk(normalized.length, cachedLen)) {
          await AIAnalysisCacheModel.incrementHitCount(fuzzy.normalized_hash);
          await AIAnalysisCacheModel.updateVariants(fuzzy.normalized_hash, content);
          const scaledResult = scaleToQuantity(fuzzy, qty);
          return {
            content,
            quantity: qty.quantity,
            unit: qty.unit,
            item: qty.item,
            analysis_result: scaledResult,
            confidence: fuzzy.confidence,
            scaled: qty.quantity !== 1,
            hitType: 'fuzzy',
            source: fuzzy.source,
          };
        }
      }
    } catch {
      // Fuzzy matching may fail if pg_trgm is not installed; fall through
    }

    return null;
  }
}
