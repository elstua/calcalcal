import { DiaryEntryModel } from "../models/DiaryEntry";
import { StreakCalculator } from "../services/streakCalculator";
import {
  AIAnalysisWorkflow,
  mergeAnalyzedBlocksWithExisting,
} from "../services/ai/analysisWorkflow";
import { AIService } from "../services/ai/service";

jest.mock("../models/AIAnalysisJob", () => ({
  AIAnalysisJobModel: {
    enqueueFullEntry: jest.fn(),
  },
}));

jest.mock("../models/DiaryEntry", () => ({
  DiaryEntryModel: {
    getById: jest.fn(),
    completeAnalysisJob: jest.fn(),
    failAnalysisJob: jest.fn(),
    startAnalysisJob: jest.fn(),
  },
}));

jest.mock("../models/Streaks", () => ({
  StreaksModel: {
    getStreaksData: jest.fn(),
  },
}));

jest.mock("../services/streakCalculator", () => ({
  StreakCalculator: {
    updateStreaksOnAnalysisComplete: jest.fn(),
  },
}));

jest.mock("../services/ai/service", () => ({
  AIService: {
    analyzeBlocks: jest.fn(),
    calculateTotals: jest.fn(),
  },
}));

jest.mock("../services/ai/providers", () => ({
  getNutritionProvider: jest.fn(),
}));

const mockedDiaryEntry = DiaryEntryModel as jest.Mocked<typeof DiaryEntryModel>;
const mockedAIService = AIService as jest.Mocked<typeof AIService>;
const mockedStreakCalculator = StreakCalculator as jest.Mocked<typeof StreakCalculator>;

describe("mergeAnalyzedBlocksWithExisting", () => {
  it("overlays a one-block AI batch onto the full existing block list", () => {
    const existingBlocks = [
      { id: "block-1", content: "eggs", calories: 200 },
      { id: "block-2", content: "toast", calories: 120 },
      { id: "block-3", content: "coffee", calories: 5 },
      { id: "block-4", content: "apple", calories: 80 },
      { id: "block-5", content: "yogurt" },
    ];
    const analyzedBlocks = [{ id: "block-5", content: "yogurt", calories: 140 }];

    const merged = mergeAnalyzedBlocksWithExisting(analyzedBlocks, existingBlocks);

    expect(merged).toHaveLength(5);
    expect(merged.map((block) => block.id)).toEqual([
      "block-1",
      "block-2",
      "block-3",
      "block-4",
      "block-5",
    ]);
    expect(merged[4]).toEqual(expect.objectContaining({ calories: 140 }));
  });

  it("appends unmatched analyzed blocks", () => {
    const merged = mergeAnalyzedBlocksWithExisting(
      [
        { id: "block-1", content: "eggs", calories: 200 },
        { id: "block-extra", content: "shared plate", calories: 60 },
      ],
      [{ id: "block-1", content: "eggs" }],
    );

    expect(merged).toHaveLength(2);
    expect(merged[0]).toEqual(expect.objectContaining({ id: "block-1", calories: 200 }));
    expect(merged[1]).toEqual(expect.objectContaining({ id: "block-extra" }));
  });

  it("preserves user-modified nutrition even when the AI returns that block", () => {
    const merged = mergeAnalyzedBlocksWithExisting(
      [{ id: "block-1", stableId: "stable-1", content: "eggs", calories: 220 }],
      [
        {
          id: "block-1",
          stableId: "stable-1",
          content: "eggs",
          calories: 180,
          protein: 12,
          userModified: true,
          lastAnalyzedAt: "before",
        },
      ],
    );

    expect(merged).toEqual([
      expect.objectContaining({
        id: "block-1",
        stableId: "stable-1",
        calories: 180,
        protein: 12,
        userModified: true,
        lastAnalyzedAt: "before",
      }),
    ]);
  });

  it("keeps existing blocks unchanged when the AI batch is empty", () => {
    const existingBlocks = [
      { id: "block-1", content: "eggs", calories: 200 },
      { id: "block-2", content: "toast", calories: 120, userModified: true },
    ];

    expect(mergeAnalyzedBlocksWithExisting([], existingBlocks)).toEqual(existingBlocks);
  });

  it("matches by stableId when ids drift", () => {
    const merged = mergeAnalyzedBlocksWithExisting(
      [{ id: "new-id", stableId: "stable-1", content: "eggs", calories: 210 }],
      [{ id: "old-id", stableId: "stable-1", content: "eggs", imageUrl: "image.jpg" }],
    );

    expect(merged).toEqual([
      expect.objectContaining({
        id: "new-id",
        stableId: "stable-1",
        imageUrl: "image.jpg",
        calories: 210,
      }),
    ]);
  });
});

describe("AIAnalysisWorkflow.executeFullEntryAnalysisJob", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockedStreakCalculator.updateStreaksOnAnalysisComplete.mockResolvedValue();
    mockedAIService.calculateTotals.mockReturnValue({
      total_calories: 640,
      total_protein: 0,
      total_fat: 0,
      total_carbs: 0,
      total_fiber: 0,
      total_sugar: 0,
      total_sodium: 0,
    });
    mockedDiaryEntry.completeAnalysisJob.mockResolvedValue({ id: "entry-1" } as any);
    mockedDiaryEntry.failAnalysisJob.mockResolvedValue({ id: "entry-1" } as any);
  });

  it("writes back the full existing block list when AI analyzes only one block", async () => {
    const existingBlocks = [
      { id: "block-1", content: "eggs", calories: 200 },
      { id: "block-2", content: "toast", calories: 120 },
      { id: "block-3", content: "coffee", calories: 5 },
      { id: "block-4", content: "apple", calories: 80 },
      { id: "block-5", content: "yogurt" },
    ];
    mockedDiaryEntry.getById.mockResolvedValue({
      id: "entry-1",
      user_id: "user-1",
      blocks: existingBlocks,
    } as any);
    mockedAIService.analyzeBlocks.mockResolvedValue([
      { id: "block-5", content: "yogurt", calories: 235 },
    ]);

    const result = await AIAnalysisWorkflow.executeFullEntryAnalysisJob({
      entryId: "entry-1",
      userId: "user-1",
      entryDate: "2026-05-20",
      jobId: "job-1",
      blocks: [{ id: "block-5", content: "yogurt" }],
    });

    expect(result).toBe("completed");
    const [, , writtenBlocks] = mockedDiaryEntry.completeAnalysisJob.mock.calls[0];
    expect(writtenBlocks).toHaveLength(5);
    expect(writtenBlocks.map((block: any) => block.id)).toEqual([
      "block-1",
      "block-2",
      "block-3",
      "block-4",
      "block-5",
    ]);
    expect(writtenBlocks[4]).toEqual(expect.objectContaining({ calories: 235 }));
    expect(mockedDiaryEntry.failAnalysisJob).not.toHaveBeenCalled();
  });
});
