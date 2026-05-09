import crypto from "crypto";
import { AIAnalysisJobModel } from "../../models/AIAnalysisJob";
import { DiaryEntryModel } from "../../models/DiaryEntry";
import { StreaksModel } from "../../models/Streaks";
import { StreakCalculator } from "../streakCalculator";
import { AIService } from "./service";
import { getNutritionProvider } from "./providers";
import { PromptContext } from "./prompts";

export interface StartFullEntryAnalysisParams {
  entryId: string;
  userId: string;
  entryDate: string | Date;
  blocks: any[];
}

export interface AnalyzeBlockContent {
  text?: string;
  imageUrl?: string;
  userProvidedData?: PromptContext["userProvidedData"];
}

export interface AnalyzeBlockParams {
  userId: string;
  entryId: string;
  blockId: string;
  content: AnalyzeBlockContent;
  userModified?: boolean;
}

export class AIAnalysisWorkflowError extends Error {
  constructor(
    message: string,
    public readonly statusCode: number,
    public readonly code: string,
  ) {
    super(message);
  }
}

function cloneBlocks(blocks: any[]): any[] {
  try {
    return JSON.parse(JSON.stringify(blocks));
  } catch (_err) {
    return blocks.map((block) => ({ ...block }));
  }
}

function mergeAnalyzedBlocksWithExisting(analyzedBlocks: any[], existingBlocks: any[]) {
  const blockMap = new Map<string, any>();
  for (const block of existingBlocks) {
    if (block.id) {
      blockMap.set(block.id, block);
    }
  }

  return analyzedBlocks.map((analyzed: any) => {
    const existing = blockMap.get(analyzed.id);
    if (!existing) {
      return analyzed;
    }

    if (existing.userModified) {
      console.log(
        `[ai:analyze] Preserving user-modified block ${analyzed.id} with calories=${existing.calories}`,
      );
      return {
        ...analyzed,
        calories: existing.calories,
        protein: existing.protein,
        fat: existing.fat,
        carbs: existing.carbs,
        fiber: existing.fiber,
        sugar: existing.sugar,
        sodium: existing.sodium,
        weight: existing.weight,
        metric_description: existing.metric_description,
        confidence: existing.confidence,
        userModified: true,
        lastAnalyzedAt: existing.lastAnalyzedAt,
        imageUrl: existing.imageUrl || analyzed.imageUrl,
        imageObjectKey: existing.imageObjectKey || analyzed.imageObjectKey,
        stableId: existing.stableId || analyzed.stableId,
      };
    }

    return {
      ...analyzed,
      imageUrl: existing.imageUrl || analyzed.imageUrl,
      imageObjectKey: existing.imageObjectKey || analyzed.imageObjectKey,
      stableId: existing.stableId || analyzed.stableId,
    };
  });
}

function sameOptionalString(left: unknown, right: unknown) {
  const leftText = typeof left === "string" ? left.trim() : "";
  const rightText = typeof right === "string" ? right.trim() : "";
  return leftText === rightText;
}

function blockStillMatchesAnalyzeInput(block: any, content: AnalyzeBlockContent) {
  if (!block) {
    return false;
  }

  if (!sameOptionalString(block.content, content.text)) {
    return false;
  }

  if (content.imageUrl && !sameOptionalString(block.imageUrl, content.imageUrl)) {
    return false;
  }

  return true;
}

export class AIAnalysisWorkflow {
  static async startFullEntryAnalysis(params: StartFullEntryAnalysisParams) {
    const jobId = crypto.randomUUID();
    const safeBlocks = cloneBlocks(params.blocks);

    const started = await DiaryEntryModel.startAnalysisJob(
      params.entryId,
      params.userId,
      jobId,
    );
    if (!started) {
      throw new Error("Entry not found");
    }

    await AIAnalysisJobModel.enqueueFullEntry({
      jobId,
      entryId: params.entryId,
      userId: params.userId,
      entryDate: params.entryDate,
      blocks: safeBlocks,
    });
    void import("./analysisWorker").then(({ AIAnalysisWorker }) => {
      AIAnalysisWorker.kick();
    });

    return { jobId };
  }

  static async analyzeBlock(params: AnalyzeBlockParams) {
    const { userId, entryId, blockId, content, userModified = false } = params;
    const entry = await DiaryEntryModel.getById(entryId);
    if (!entry || entry.user_id !== userId) {
      throw new AIAnalysisWorkflowError("Entry not found", 404, "entry_not_found");
    }

    const hasText = !!(content.text && content.text.trim());
    const hasImage = !!(content.imageUrl && content.imageUrl.trim());

    let scenario: PromptContext["scenario"];
    if (hasText && hasImage) {
      scenario = "multimodal";
    } else if (hasImage && !hasText) {
      scenario = "image-only";
    } else if (hasText && !hasImage) {
      scenario = userModified ? "manual-update" : "text-only";
    } else {
      throw new AIAnalysisWorkflowError(
        "Either text or imageUrl must be provided",
        400,
        "missing_analysis_content",
      );
    }

    const mealContext = (entry.blocks || [])
      .filter((b: any) => b.id !== blockId && (b.description || b.text))
      .map((b: any) => ({
        description: b.description || b.text,
        calories: b.calories,
        protein: b.protein,
        fat: b.fat,
        carbs: b.carbs,
        weight: b.weight,
        metric_description: b.metric_description,
      }))
      .filter((item: any) => item.description);

    console.log(
      `[analyze-block] Extracted meal context:`,
      JSON.stringify(
        {
          totalBlocks: entry.blocks?.length || 0,
          contextItems: mealContext.length,
          context: mealContext,
        },
        null,
        2,
      ),
    );

    const promptContext: PromptContext = {
      text: content.text || undefined,
      imageUrl: content.imageUrl || undefined,
      userModified,
      userProvidedData: content.userProvidedData || undefined,
      scenario,
      mealContext: mealContext.length > 0 ? mealContext : undefined,
    };

    console.log(
      `[analyze-block] user=${userId} entry=${entryId} block=${blockId} scenario=${scenario} hasText=${hasText} hasImage=${hasImage} userModified=${userModified}`,
    );
    console.log(
      `[analyze-block] Prompt context:`,
      JSON.stringify(promptContext, null, 2),
    );

    const jobId = crypto.randomUUID();
    const started = await DiaryEntryModel.startAnalysisJob(entryId, userId, jobId);
    if (!started) {
      throw new AIAnalysisWorkflowError("Entry not found", 404, "entry_not_found");
    }

    const provider = getNutritionProvider();
    const providerName = (process.env.AI_PROVIDER || "openai").toLowerCase();
    const model =
      providerName === "gemini"
        ? process.env.AI_GEMINI_MODEL || "gemini-2.5-flash"
        : process.env.AI_OPENAI_MODEL || "gpt-4o-mini";
    const temperature = Number(process.env.AI_TEMPERATURE ?? 0.2);

    console.time("[analyze-block] ai_call");
    let analysis: any;

    try {
      const timeoutEnv = Number(process.env.AI_PROVIDER_TIMEOUT_MS ?? 60_000);
      const timeout =
        Number.isFinite(timeoutEnv) && timeoutEnv > 0
          ? Math.floor(timeoutEnv)
          : 60_000;

      const timeoutPromise = new Promise((_, reject) => {
        setTimeout(() => reject(new Error("Request timeout")), timeout);
      });

      try {
        analysis = await Promise.race([
          provider.analyze(content.text || "", {
            temperature,
            model,
            imageUrl: content.imageUrl,
            context: promptContext,
          }),
          timeoutPromise,
        ]);
      } catch (error: any) {
        if (error.message === "Request timeout") {
          console.error(
            "[analyze-block] Request timed out after",
            timeout,
            "ms",
          );
          await DiaryEntryModel.failAnalysisJob(entryId, jobId, "Request timeout");
          throw new AIAnalysisWorkflowError(
            "The nutrition analysis took too long to complete. Please try again.",
            408,
            "request_timeout",
          );
        }
        throw error;
      }
    } catch (error: any) {
      if (error instanceof AIAnalysisWorkflowError) {
        throw error;
      }

      console.error("[analyze-block] Provider call failed", {
        message: error?.message,
      });

      await DiaryEntryModel.failAnalysisJob(
        entryId,
        jobId,
        error?.message || "Unknown error",
      );

      throw new AIAnalysisWorkflowError(
        error?.message || "Unknown error",
        500,
        "ai_analysis_failed",
      );
    } finally {
      console.timeEnd("[analyze-block] ai_call");
    }

    const updatedBlocks = (entry.blocks || []).map((block: any) => {
      if (block.id === blockId) {
        return {
          ...block,
          ...analysis,
          userModified: userModified || false,
          lastAnalyzedAt: new Date().toISOString(),
        };
      }
      return block;
    });

    const totals = AIService.calculateTotals(updatedBlocks);
    let updatedEntry = await DiaryEntryModel.completeAnalysisJob(
      entryId,
      jobId,
      updatedBlocks,
      totals,
    );

    if (!updatedEntry) {
      const latestEntry = await DiaryEntryModel.getById(entryId);
      const latestBlock = latestEntry?.blocks?.find((block: any) => block.id === blockId);

      if (!latestEntry || !blockStillMatchesAnalyzeInput(latestBlock, content)) {
        throw new AIAnalysisWorkflowError(
          "Analysis result is stale",
          409,
          "stale_analysis_result",
        );
      }

      const retryJobId = crypto.randomUUID();
      const retryStarted = await DiaryEntryModel.startAnalysisJob(entryId, userId, retryJobId);
      if (!retryStarted) {
        throw new AIAnalysisWorkflowError("Entry not found", 404, "entry_not_found");
      }

      const retryBlocks = (latestEntry.blocks || []).map((block: any) => {
        if (block.id === blockId) {
          return {
            ...block,
            ...analysis,
            userModified: userModified || false,
            lastAnalyzedAt: new Date().toISOString(),
          };
        }
        return block;
      });
      const retryTotals = AIService.calculateTotals(retryBlocks);
      updatedEntry = await DiaryEntryModel.completeAnalysisJob(
        entryId,
        retryJobId,
        retryBlocks,
        retryTotals,
      );

      if (!updatedEntry) {
        throw new AIAnalysisWorkflowError(
          "Analysis result is stale",
          409,
          "stale_analysis_result",
        );
      }
    }

    console.log(
      `[analyze-block] success calories=${analysis.calories} protein=${analysis.protein} fat=${analysis.fat} carbs=${analysis.carbs} weight=${analysis.weight || "N/A"} metric_description=${analysis.metric_description || "N/A"}`,
    );

    let streaksData = null;
    try {
      await StreakCalculator.updateStreaksOnAnalysisComplete(userId, entry.date);
      streaksData = await StreaksModel.getStreaksData(userId);
      console.log(
        `[analyze-block] streaks updated: current=${streaksData?.currentStreak}`,
      );
    } catch (streakError) {
      console.error("[analyze-block] Error updating streaks:", streakError);
    }

    return {
      blockId,
      entryId,
      ...analysis,
      totals,
      streaks: streaksData,
    };
  }

  static async executeFullEntryAnalysisJob(
    params: StartFullEntryAnalysisParams & { jobId: string },
  ) {
    const { entryId, userId, entryDate, blocks, jobId } = params;

    console.log(
      `[ai:analyze] job start entry=${entryId} job=${jobId} blocks=${blocks.length}`,
    );

    try {
      const existingEntry = await DiaryEntryModel.getById(entryId);
      if (!existingEntry) {
        throw new Error("Entry not found");
      }

      const analyzedBlocks = await AIService.analyzeBlocks(blocks);
      const mergedBlocks = mergeAnalyzedBlocksWithExisting(
        analyzedBlocks,
        existingEntry.blocks || [],
      );
      const totals = AIService.calculateTotals(mergedBlocks);

      const completed = await DiaryEntryModel.completeAnalysisJob(
        entryId,
        jobId,
        mergedBlocks,
        totals,
      );

      if (!completed) {
        console.warn(`[ai:analyze] stale job skipped entry=${entryId} job=${jobId}`);
        return "stale" as const;
      }

      console.log(`[ai:analyze] job completed entry=${entryId} job=${jobId}`);

      try {
        await StreakCalculator.updateStreaksOnAnalysisComplete(userId, entryDate);
        console.log(`[ai:analyze] streaks updated for user=${userId}`);
      } catch (streakError) {
        console.error("[ai:analyze] Error updating streaks:", streakError);
      }
      return "completed" as const;
    } catch (error: any) {
      const markedFailed = await DiaryEntryModel.failAnalysisJob(
        entryId,
        jobId,
        error?.message || "Unknown error",
      );

      if (!markedFailed) {
        console.warn(
          `[ai:analyze] stale job failed but ignored entry=${entryId} job=${jobId}`,
        );
        return "stale" as const;
      }

      console.error("[ai:analyze] job failed", {
        entryId,
        jobId,
        message: error?.message,
      });
      throw error;
    }
  }
}
