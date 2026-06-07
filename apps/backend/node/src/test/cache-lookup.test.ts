import { CacheLookupService } from '../services/ai/cacheLookup';
import { AIAnalysisCacheModel } from '../models/AIAnalysisCache';

// Mock database
jest.mock('../services/database', () => ({
  __esModule: true,
  default: {
    query: jest.fn(),
  },
}));

// Spy on model methods
jest.mock('../models/AIAnalysisCache');

const MockedCacheModel = AIAnalysisCacheModel as jest.MockedClass<typeof AIAnalysisCacheModel>;

describe('CacheLookupService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('returns exact normalized match with scaling', async () => {
    const cachedRow = {
      analysis_result: {
        calories: 78,
        protein: 6.3,
        fat: 5.3,
        carbs: 0.6,
        fiber: 0,
        sugar: 0.6,
        sodium: 62,
      },
      confidence: 0.95,
      normalized_content: 'egg',
      hit_count: 5,
      source: 'llm',
      unit_calories: 78,
      normalized_hash: 'somehash',
    };

    (AIAnalysisCacheModel.getByNormalizedHash as jest.Mock).mockResolvedValue(cachedRow);
    (AIAnalysisCacheModel.incrementHitCount as jest.Mock).mockResolvedValue(undefined);
    (AIAnalysisCacheModel.updateVariants as jest.Mock).mockResolvedValue(undefined);

    const result = await CacheLookupService.lookup('3 eggs');

    expect(result).not.toBeNull();
    expect(result!.hitType).toBe('exact');
    expect(result!.quantity).toBe(3);
    expect(result!.item).toBe('egg');
    expect(result!.analysis_result.calories).toBe(78 * 3);
    expect(result!.confidence).toBe(0.95);
    expect(AIAnalysisCacheModel.incrementHitCount).toHaveBeenCalled();
  });

  it('returns fuzzy match when exact match misses', async () => {
    (AIAnalysisCacheModel.getByNormalizedHash as jest.Mock).mockResolvedValue(null);

    const fuzzyRow = {
      analysis_result: {
        calories: 65,
        protein: 3.5,
        fat: 3.5,
        carbs: 5,
        fiber: 0,
        sugar: 5,
        sodium: 30,
      },
      confidence: 0.8,
      normalized_content: 'cappuccino',
      hit_count: 10,
      source: 'llm',
      unit_calories: 65,
      normalized_hash: 'fuzzyhash',
    };

    (AIAnalysisCacheModel.getByFuzzyMatch as jest.Mock).mockResolvedValue(fuzzyRow);
    (AIAnalysisCacheModel.incrementHitCount as jest.Mock).mockResolvedValue(undefined);
    (AIAnalysisCacheModel.updateVariants as jest.Mock).mockResolvedValue(undefined);

    const result = await CacheLookupService.lookup('cappuccino');

    expect(result).not.toBeNull();
    expect(result!.hitType).toBe('fuzzy');
    expect(result!.item).toBe('cappuccino');
    expect(result!.analysis_result.calories).toBe(65);
  });

  it('returns null on complete cache miss', async () => {
    (AIAnalysisCacheModel.getByNormalizedHash as jest.Mock).mockResolvedValue(null);
    (AIAnalysisCacheModel.getByFuzzyMatch as jest.Mock).mockResolvedValue(null);

    const result = await CacheLookupService.lookup('exotic dragon fruit smoothie');

    expect(result).toBeNull();
  });

  it('increments hit_count on cache hit', async () => {
    const cachedRow = {
      analysis_result: { calories: 100, protein: 0, fat: 0, carbs: 0, fiber: 0, sugar: 0, sodium: 0 },
      confidence: 0.9,
      normalized_hash: 'testhash',
      source: 'llm',
      unit_calories: 100,
    };

    (AIAnalysisCacheModel.getByNormalizedHash as jest.Mock).mockResolvedValue(cachedRow);
    (AIAnalysisCacheModel.incrementHitCount as jest.Mock).mockResolvedValue(undefined);
    (AIAnalysisCacheModel.updateVariants as jest.Mock).mockResolvedValue(undefined);

    await CacheLookupService.lookup('cappuccino');

    expect(AIAnalysisCacheModel.incrementHitCount).toHaveBeenCalledWith('testhash');
  });

  it('handles multilingual queries with same result', async () => {
    const cachedRow = {
      analysis_result: {
        calories: 78,
        protein: 6.3,
        fat: 5.3,
        carbs: 0.6,
        fiber: 0,
        sugar: 0.6,
        sodium: 62,
      },
      confidence: 0.9,
      normalized_content: 'egg',
      hit_count: 2,
      source: 'llm',
      unit_calories: 78,
      normalized_hash: 'eggcanonicalhash',
    };

    (AIAnalysisCacheModel.getByNormalizedHash as jest.Mock).mockResolvedValue(cachedRow);
    (AIAnalysisCacheModel.incrementHitCount as jest.Mock).mockResolvedValue(undefined);
    (AIAnalysisCacheModel.updateVariants as jest.Mock).mockResolvedValue(undefined);

    // Both Russian and English should resolve to the same hash
    const resultEn = await CacheLookupService.lookup('egg');
    const resultRu = await CacheLookupService.lookup('яйцо');

    expect(resultEn).not.toBeNull();
    expect(resultRu).not.toBeNull();
    expect(resultEn!.item).toBe('egg');
    expect(resultRu!.item).toBe('egg');
    // Both should call getByNormalizedHash with the same canonical hash
    const calls = (AIAnalysisCacheModel.getByNormalizedHash as jest.Mock).mock.calls;
    expect(calls[0][0]).toBe(calls[1][0]);
  });

  it('scales correctly for quantity=1 (no scaling needed)', async () => {
    const cachedRow = {
      analysis_result: {
        calories: 65,
        protein: 3.5,
        fat: 3.5,
        carbs: 5,
        fiber: 0,
        sugar: 5,
        sodium: 30,
      },
      confidence: 0.9,
      source: 'llm',
      unit_calories: 65,
      normalized_hash: 'caphash',
    };

    (AIAnalysisCacheModel.getByNormalizedHash as jest.Mock).mockResolvedValue(cachedRow);
    (AIAnalysisCacheModel.incrementHitCount as jest.Mock).mockResolvedValue(undefined);
    (AIAnalysisCacheModel.updateVariants as jest.Mock).mockResolvedValue(undefined);

    const result = await CacheLookupService.lookup('a cappuccino');
    expect(result!.analysis_result.calories).toBe(65);
    expect(result!.scaled).toBe(false);
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Multi-item assembly
  // ────────────────────────────────────────────────────────────────────────────

  describe('multi-item blocks', () => {
    const cappuccinoRow = {
      analysis_result: { calories: 65, protein: 3.5, fat: 3.5, carbs: 5, fiber: 0, sugar: 5, sodium: 30 },
      confidence: 0.9,
      normalized_content: 'cappuccino',
      source: 'llm-item',
      unit_calories: 65,
      normalized_hash: 'cappuccinohash',
    };
    const bananaRow = {
      analysis_result: { calories: 90, protein: 1.1, fat: 0.3, carbs: 23, fiber: 2.6, sugar: 12, sodium: 1 },
      confidence: 0.85,
      normalized_content: 'banana',
      source: 'llm-item',
      unit_calories: 90,
      normalized_hash: 'bananahash',
    };

    it('assembles combined result when all segments hit', async () => {
      // Both items are in cache: cappuccino then banana (two lookups)
      (AIAnalysisCacheModel.getByNormalizedHash as jest.Mock)
        .mockResolvedValueOnce(cappuccinoRow)  // cappuccino lookup
        .mockResolvedValueOnce(bananaRow);      // banana lookup
      (AIAnalysisCacheModel.incrementHitCount as jest.Mock).mockResolvedValue(undefined);
      (AIAnalysisCacheModel.updateVariants as jest.Mock).mockResolvedValue(undefined);

      const result = await CacheLookupService.lookup('cappuccino and banana');

      expect(result).not.toBeNull();
      expect(result!.hitType).toBe('assembled');
      expect(result!.analysis_result.calories).toBe(65 + 90); // 155
      expect(result!.analysis_result.protein).toBeCloseTo(3.5 + 1.1, 1);
      expect(Array.isArray(result!.analysis_result.items)).toBe(true);
      expect(result!.analysis_result.items).toHaveLength(2);
      expect(result!.analysis_result.items[0].source_text).toBe('cappuccino');
      expect(result!.analysis_result.items[1].source_text).toBe('banana');
    });

    it('returns null (forces LLM) when any segment is not cached', async () => {
      // cappuccino hits, banana misses entirely
      (AIAnalysisCacheModel.getByNormalizedHash as jest.Mock)
        .mockResolvedValueOnce(cappuccinoRow) // cappuccino hit
        .mockResolvedValueOnce(null);          // banana miss
      (AIAnalysisCacheModel.getByFuzzyMatch as jest.Mock).mockResolvedValue(null);
      (AIAnalysisCacheModel.incrementHitCount as jest.Mock).mockResolvedValue(undefined);
      (AIAnalysisCacheModel.updateVariants as jest.Mock).mockResolvedValue(undefined);

      const result = await CacheLookupService.lookup('cappuccino and banana');

      expect(result).toBeNull();
    });

    it('does NOT return cappuccino-only calories for "cappuccino and banana"', async () => {
      // This is the original bug: fuzzy matching "cappuccino" against the block.
      // With the new code the block is split first, so each segment is looked up
      // individually. If banana is uncached the whole result must be null.
      (AIAnalysisCacheModel.getByNormalizedHash as jest.Mock)
        .mockResolvedValueOnce(cappuccinoRow)
        .mockResolvedValueOnce(null); // banana not cached
      (AIAnalysisCacheModel.getByFuzzyMatch as jest.Mock).mockResolvedValue(null);
      (AIAnalysisCacheModel.incrementHitCount as jest.Mock).mockResolvedValue(undefined);
      (AIAnalysisCacheModel.updateVariants as jest.Mock).mockResolvedValue(undefined);

      const result = await CacheLookupService.lookup('cappuccino and banana');

      // Must be null, NOT cappuccino-only
      expect(result).toBeNull();
    });

    it('assembles three items correctly', async () => {
      const chickenRow = {
        analysis_result: { calories: 165, protein: 31, fat: 3.6, carbs: 0, fiber: 0, sugar: 0, sodium: 74 },
        confidence: 0.88,
        normalized_content: 'chicken breast',
        source: 'llm-item',
        unit_calories: 165,
        normalized_hash: 'chickenhash',
      };
      const riceRow = {
        analysis_result: { calories: 200, protein: 4.2, fat: 0.4, carbs: 44, fiber: 0.6, sugar: 0, sodium: 2 },
        confidence: 0.9,
        normalized_content: 'rice',
        source: 'llm-item',
        unit_calories: 200,
        normalized_hash: 'ricehash',
      };
      const beansRow = {
        analysis_result: { calories: 110, protein: 7, fat: 0.5, carbs: 20, fiber: 6, sugar: 0, sodium: 240 },
        confidence: 0.87,
        normalized_content: 'beans',
        source: 'llm-item',
        unit_calories: 110,
        normalized_hash: 'beanshash',
      };

      (AIAnalysisCacheModel.getByNormalizedHash as jest.Mock)
        .mockResolvedValueOnce(chickenRow)
        .mockResolvedValueOnce(riceRow)
        .mockResolvedValueOnce(beansRow);
      (AIAnalysisCacheModel.incrementHitCount as jest.Mock).mockResolvedValue(undefined);
      (AIAnalysisCacheModel.updateVariants as jest.Mock).mockResolvedValue(undefined);

      const result = await CacheLookupService.lookup('chicken breast, rice and beans');

      expect(result).not.toBeNull();
      expect(result!.hitType).toBe('assembled');
      expect(result!.analysis_result.calories).toBe(165 + 200 + 110); // 475
      expect(result!.analysis_result.items).toHaveLength(3);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Length-ratio guard on fuzzy match
  // ────────────────────────────────────────────────────────────────────────────

  describe('length-ratio guard on fuzzy', () => {
    it('rejects a fuzzy match when cached entry is much shorter than query', async () => {
      // Query: "cappuccino with oat milk" (long), cached: "cap" (very short) — ratio > 1.5
      (AIAnalysisCacheModel.getByNormalizedHash as jest.Mock).mockResolvedValue(null);
      (AIAnalysisCacheModel.getByFuzzyMatch as jest.Mock).mockResolvedValue({
        analysis_result: { calories: 10, protein: 0, fat: 0, carbs: 0, fiber: 0, sugar: 0, sodium: 0 },
        confidence: 0.7,
        normalized_content: 'cap', // length 3 vs query length ~24 → ratio ≈ 8 ✗
        source: 'llm',
        unit_calories: 10,
        normalized_hash: 'caphash',
      });
      (AIAnalysisCacheModel.incrementHitCount as jest.Mock).mockResolvedValue(undefined);
      (AIAnalysisCacheModel.updateVariants as jest.Mock).mockResolvedValue(undefined);

      const result = await CacheLookupService.lookup('cappuccino with oat milk');

      expect(result).toBeNull();
    });

    it('accepts a fuzzy match when lengths are within acceptable ratio', async () => {
      // Query: "cappucino" (typo, 9 chars), cached: "cappuccino" (10 chars) → ratio ≈ 0.9 ✓
      (AIAnalysisCacheModel.getByNormalizedHash as jest.Mock).mockResolvedValue(null);
      (AIAnalysisCacheModel.getByFuzzyMatch as jest.Mock).mockResolvedValue({
        analysis_result: { calories: 65, protein: 3.5, fat: 3.5, carbs: 5, fiber: 0, sugar: 5, sodium: 30 },
        confidence: 0.8,
        normalized_content: 'cappuccino', // length 10 vs 9 → ratio ≈ 0.9 ✓
        source: 'llm',
        unit_calories: 65,
        normalized_hash: 'cappuccinohash',
      });
      (AIAnalysisCacheModel.incrementHitCount as jest.Mock).mockResolvedValue(undefined);
      (AIAnalysisCacheModel.updateVariants as jest.Mock).mockResolvedValue(undefined);

      const result = await CacheLookupService.lookup('cappucino'); // typo

      expect(result).not.toBeNull();
      expect(result!.hitType).toBe('fuzzy');
      expect(result!.analysis_result.calories).toBe(65);
    });
  });
});
