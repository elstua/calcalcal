import { AIAnalysisCacheModel, AIAnalysisCacheRow } from '../../models/AIAnalysisCache';
import {
  normalize,
  extractQuantity,
  findCanonicalForm,
  hashNormalized,
  normalizeForHash,
  ExtractedQuantity,
} from './normalization';

export interface CacheLookupResult {
  /** The original content string the user provided */
  content: string;
  /** Extracted quantity info */
  quantity: number;
  unit: string;
  item: string;
  /** The cached analysis result (per-unit nutrition) */
  analysis_result: any;
  confidence: number;
  /** Whether this was scaled from per-unit values */
  scaled: boolean;
  /** How was the cache hit produced */
  hitType: 'exact' | 'fuzzy';
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

  // If we have stored per-unit values, scale them
  if (cached.unit_calories != null) {
    const unitFactor = Number(cached.unit_calories) / (Number(result.calories) || 1);
    // If analysis_result is already per-unit, just multiply
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

  // Fallback: if no unit_calories stored, scale proportionally anyway
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

export class CacheLookupService {
  /**
   * Perform a smart cache lookup for food content.
   * Tries exact normalized match first, then fuzzy match via pg_trgm.
   * Returns scaled nutrition result on hit, or null on miss.
   */
  static async lookup(content: string): Promise<CacheLookupResult | null> {
    const normalized = normalize(content);
    const canonicalBase = normalizeForHash(content);
    const hash = hashNormalized(canonicalBase);
    const qty = extractQuantity(content);

    // 1. Exact normalized hash match
    const exact = await AIAnalysisCacheModel.getByNormalizedHash(hash);
    if (exact) {
      const effectiveHash = exact.normalized_hash || hash;
      await AIAnalysisCacheModel.incrementHitCount(effectiveHash);
      // Track the original variant
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

    // 2. Fuzzy match via pg_trgm
    try {
      const fuzzy = await AIAnalysisCacheModel.getByFuzzyMatch(normalized);
      if (fuzzy && fuzzy.normalized_hash) {
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
    } catch {
      // Fuzzy matching may fail if pg_trgm is not installed; fall through
    }

    return null;
  }
}
