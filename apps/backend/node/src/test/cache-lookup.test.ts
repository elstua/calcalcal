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
});
