import { AIAnalysisCacheModel } from "../models/AIAnalysisCache";
import { getNutritionProvider } from "../services/ai/providers";
import { AIService } from "../services/ai/service";

jest.mock("../models/AIAnalysisCache", () => ({
  AIAnalysisCacheModel: {
    getByContentHash: jest.fn(),
    insert: jest.fn(),
  },
}));

jest.mock("../services/ai/providers", () => ({
  getNutritionProvider: jest.fn(),
}));

const mockedGetNutritionProvider =
  getNutritionProvider as jest.MockedFunction<typeof getNutritionProvider>;
const mockedCache = AIAnalysisCacheModel as jest.Mocked<typeof AIAnalysisCacheModel>;

describe("AIService image context", () => {
  const analyze = jest.fn();

  beforeEach(() => {
    jest.clearAllMocks();
    mockedGetNutritionProvider.mockReturnValue({ analyze });
    analyze.mockResolvedValue({
      description: "Chicken salad",
      calories: 420,
      protein: 32,
      fat: 18,
      carbs: 28,
      fiber: 4,
      sugar: 6,
      sodium: 620,
      confidence: 0.9,
    });
  });

  it("passes image URLs to provider when reanalyzing image-backed text blocks", async () => {
    const [result] = await AIService.analyzeBlocks([
      {
        id: "block-1",
        content: "make this a chicken salad with dressing",
        imageUrl: "https://media.calcalcal.app/uploads/salad.jpg",
      },
    ]);

    expect(mockedCache.getByContentHash).not.toHaveBeenCalled();
    expect(mockedCache.insert).not.toHaveBeenCalled();
    expect(analyze).toHaveBeenCalledWith(
      "make this a chicken salad with dressing",
      expect.objectContaining({
        imageUrl: "https://media.calcalcal.app/uploads/salad.jpg",
        context: expect.objectContaining({
          text: "make this a chicken salad with dressing",
          imageUrl: "https://media.calcalcal.app/uploads/salad.jpg",
          scenario: "multimodal",
        }),
      }),
    );
    expect(result).toEqual(
      expect.objectContaining({
        id: "block-1",
        imageUrl: "https://media.calcalcal.app/uploads/salad.jpg",
        calories: 420,
      }),
    );
  });

  it("continues using text cache for text-only blocks", async () => {
    mockedCache.getByContentHash.mockResolvedValue({
      analysis_result: { description: "Greek yogurt", calories: 140 },
      confidence: 0.8,
    });

    const [result] = await AIService.analyzeBlocks([
      { id: "block-2", content: "greek yogurt" },
    ]);

    expect(analyze).not.toHaveBeenCalled();
    expect(mockedCache.insert).not.toHaveBeenCalled();
    expect(result).toEqual(
      expect.objectContaining({
        id: "block-2",
        calories: 140,
        confidence: 0.8,
      }),
    );
  });
});
