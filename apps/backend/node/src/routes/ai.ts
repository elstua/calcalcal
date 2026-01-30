import { Router } from "express";
import { AuthRequest, authenticateToken } from "../middleware/auth";
import { DiaryEntryModel } from "../models/DiaryEntry";
import { StreaksModel } from "../models/Streaks";
import { AIService } from "../services/ai/service";
import { StreakCalculator } from "../services/streakCalculator";
import Database from "../services/database";
import { OpenAI } from "openai";
import * as fs from "fs";
import * as path from "path";
import { getNutritionProvider } from "../services/ai/providers";
import { PromptTemplateBuilder, PromptContext } from "../services/ai/prompts";

const router = Router();

router.use(authenticateToken);

const activeAnalysisJobs = new Map<string, symbol>();

function cloneBlocks(blocks: any[]): any[] {
  try {
    return JSON.parse(JSON.stringify(blocks));
  } catch (_err) {
    // Fallback shallow copy
    return blocks.map((block) => ({ ...block }));
  }
}

function queueAnalysisJob(entryId: string, blocks: any[], userId: string, entryDate: string | Date) {
  const jobToken = Symbol(entryId);
  const safeBlocks = cloneBlocks(blocks);
  activeAnalysisJobs.set(entryId, jobToken);

  setImmediate(async () => {
    console.log(
      `[ai:analyze] job start entry=${entryId} blocks=${safeBlocks.length}`,
    );
    try {
      // Fetch existing blocks to preserve client metadata
      const existingEntry = await DiaryEntryModel.getById(entryId);
      const existingBlocks = existingEntry?.blocks || [];

      // Build a map of block IDs to preserve client metadata
      const blockMap = new Map();
      for (const block of existingBlocks) {
        if (block.id) {
          blockMap.set(block.id, block);
        }
      }

      const analyzedBlocks = await AIService.analyzeBlocks(safeBlocks);

      // Merge: preserve metadata AND nutrition data from user-modified blocks
      // CRITICAL: User-modified blocks should NEVER have their nutrition overwritten
      const mergedBlocks = analyzedBlocks.map((analyzed: any) => {
        const existing = blockMap.get(analyzed.id);
        if (existing) {
          // If the existing block was user-modified, preserve ALL its nutrition data
          // The AI service already skips re-analyzing userModified blocks,
          // but we must also preserve the data during the merge
          if (existing.userModified) {
            console.log(`[ai:analyze] Preserving user-modified block ${analyzed.id} with calories=${existing.calories}`);
            return {
              ...analyzed,
              // Preserve ALL nutrition fields from user-modified block
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
              // Preserve other metadata
              imageUrl: existing.imageUrl || analyzed.imageUrl,
              imageObjectKey: existing.imageObjectKey || analyzed.imageObjectKey,
              stableId: existing.stableId || analyzed.stableId,
            };
          }
          // Non-user-modified blocks: just preserve metadata
          return {
            ...analyzed,
            imageUrl: existing.imageUrl || analyzed.imageUrl,
            imageObjectKey: existing.imageObjectKey || analyzed.imageObjectKey,
            stableId: existing.stableId || analyzed.stableId,
          };
        }
        return analyzed;
      });

      const totals = AIService.calculateTotals(mergedBlocks);

      const isLatest = activeAnalysisJobs.get(entryId) === jobToken;
      if (!isLatest) {
        console.warn(`[ai:analyze] stale job skipped entry=${entryId}`);
        return;
      }

      await Database.query(
        `UPDATE diary_entries SET
           blocks = $1,
           total_calories = $2,
           total_protein = $3,
           total_fat = $4,
           total_carbs = $5,
           total_fiber = $6,
           total_sugar = $7,
           total_sodium = $8,
           ai_analysis_status = $9,
           ai_analysis_error = NULL
         WHERE id = $10`,
        [
          JSON.stringify(mergedBlocks),
          totals.total_calories,
          totals.total_protein,
          totals.total_fat,
          totals.total_carbs,
          totals.total_fiber,
          totals.total_sugar,
          totals.total_sodium,
          "completed",
          entryId,
        ],
      );
      console.log(`[ai:analyze] job completed entry=${entryId}`);

      // Update streaks after successful AI analysis
      try {
        await StreakCalculator.updateStreaksOnAnalysisComplete(userId, entryDate);
        console.log(`[ai:analyze] streaks updated for user=${userId}`);
      } catch (streakError) {
        console.error('[ai:analyze] Error updating streaks:', streakError);
        // Don't fail the job if streak update fails
      }
    } catch (error: any) {
      const isLatest = activeAnalysisJobs.get(entryId) === jobToken;
      if (!isLatest) {
        console.warn(
          `[ai:analyze] stale job failed but ignored entry=${entryId}`,
        );
        return;
      }

      console.error("[ai:analyze] job failed", {
        entryId,
        message: error?.message,
      });
      await Database.query(
        `UPDATE diary_entries SET ai_analysis_status = $1, ai_analysis_error = $2 WHERE id = $3`,
        ["failed", error?.message || "Unknown error", entryId],
      );
    } finally {
      if (activeAnalysisJobs.get(entryId) === jobToken) {
        activeAnalysisJobs.delete(entryId);
      }
    }
  });
}

// POST /api/ai/analyze-block
router.post("/analyze-block", unifiedAnalyzeBlockHandler);

// Unified analyze-block handler
async function unifiedAnalyzeBlockHandler(req: AuthRequest, res: any) {
  try {
    const { blockId, entryId, content, userModified = false } = req.body;
    const userId = req.userId!;

    if (!blockId || !entryId || !content) {
      return res.status(400).json({
        error: "blockId, entryId, and content are required",
      });
    }

    // Verify entry ownership
    const entry = await DiaryEntryModel.getById(entryId);
    if (!entry || entry.user_id !== userId) {
      return res.status(404).json({ error: "Entry not found" });
    }

    // Extract nutrition data from other blocks for context
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

    // Determine analysis scenario and build context
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
      return res.status(400).json({
        error: "Either text or imageUrl must be provided",
      });
    }

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

    // Get nutrition provider and perform analysis
    const provider = getNutritionProvider();
    const model =
      process.env.AI_MODEL ||
      (process.env.AI_PROVIDER === "gemini"
        ? process.env.AI_GEMINI_MODEL
        : process.env.AI_OPENAI_MODEL) ||
      "gpt-4o-mini";
    const temperature = Number(process.env.AI_TEMPERATURE ?? 0.2);

    // Set analysis status in database
    await Database.query(
      `UPDATE diary_entries SET ai_analysis_status = $1, ai_analysis_error = NULL WHERE id = $2`,
      ["processing", entryId],
    );

    // Perform the analysis
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
          await Database.query(
            `UPDATE diary_entries SET ai_analysis_status = $1, ai_analysis_error = $2 WHERE id = $3`,
            ["failed", "Request timeout", entryId],
          );
          return res.status(408).json({
            error: "Request timeout",
            message:
              "The nutrition analysis took too long to complete. Please try again.",
          });
        }
        throw error;
      }
    } catch (error: any) {
      console.error("[analyze-block] Provider call failed", {
        message: error?.message,
      });

      await Database.query(
        `UPDATE diary_entries SET ai_analysis_status = $1, ai_analysis_error = $2 WHERE id = $3`,
        ["failed", error?.message || "Unknown error", entryId],
      );

      return res.status(500).json({
        error: "AI analysis failed",
        message: error?.message || "Unknown error",
      });
    }

    console.timeEnd("[analyze-block] ai_call");

    // Update the block in the entry with new analysis data
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

    // Calculate new totals
    const totals = AIService.calculateTotals(updatedBlocks);

    // Update the database
    await Database.query(
      `UPDATE diary_entries SET
         blocks = $1,
         total_calories = $2,
         total_protein = $3,
         total_fat = $4,
         total_carbs = $5,
         total_fiber = $6,
         total_sugar = $7,
         total_sodium = $8,
         ai_analysis_status = $9,
         ai_analysis_error = NULL
       WHERE id = $10`,
      [
        JSON.stringify(updatedBlocks),
        totals.total_calories,
        totals.total_protein,
        totals.total_fat,
        totals.total_carbs,
        totals.total_fiber,
        totals.total_sugar,
        totals.total_sodium,
        "completed",
        entryId,
      ],
    );

    console.log(
      `[analyze-block] success calories=${analysis.calories} protein=${analysis.protein} fat=${analysis.fat} carbs=${analysis.carbs} weight=${analysis.weight || "N/A"} metric_description=${analysis.metric_description || "N/A"}`,
    );

    // Update streaks after successful AI analysis (validated food items)
    let streaksData = null;
    try {
      await StreakCalculator.updateStreaksOnAnalysisComplete(userId, entry.date);
      streaksData = await StreaksModel.getStreaksData(userId);
      console.log(`[analyze-block] streaks updated: current=${streaksData?.currentStreak}`);
    } catch (streakError) {
      console.error('[analyze-block] Error updating streaks:', streakError);
      // Don't fail the request if streak update fails
    }

    // Return the updated block data with streaks
    const result = {
      blockId,
      entryId,
      ...analysis,
      totals,
      streaks: streaksData,
    };

    res.json(result);
  } catch (error: any) {
    console.error(
      "/analyze-block error",
      error?.response?.data || error?.message || error,
    );
    res
      .status(500)
      .json({ error: "Internal server error", message: error?.message });
  }
}

// Legacy endpoint - redirects to new unified endpoint
// POST /api/ai/analyze
router.post("/analyze", async (req: AuthRequest, res) => {
  try {
    const { entryId, blocks } = req.body;
    const userId = req.userId!;

    if (!entryId || !Array.isArray(blocks)) {
      return res.status(400).json({
        error: "entryId and blocks array are required",
      });
    }

    const entry = await DiaryEntryModel.getById(entryId);
    if (!entry || entry.user_id !== userId) {
      return res.status(404).json({ error: "Entry not found" });
    }

    await Database.query(
      `UPDATE diary_entries SET ai_analysis_status = $1, ai_analysis_error = NULL WHERE id = $2`,
      ["processing", entryId],
    );

    queueAnalysisJob(entryId, blocks, userId, entry.date);

    return res
      .status(202)
      .json({ success: true, status: "processing", updatedBlocksCount: null });
  } catch (error) {
    res.status(500).json({ error: "Internal server error" });
  }
});

// Legacy endpoint - redirects to new unified endpoint
// POST /api/ai/analyze-image
router.post("/analyze-image", async (req: AuthRequest, res) => {
  try {
    const { imageUrl, entryId, blockId } = req.body || {};
    const userId = req.userId!;

    if (!imageUrl || !entryId || !blockId) {
      return res.status(400).json({
        error: "imageUrl, entryId, and blockId are required",
      });
    }

    // Create block content structure for unified endpoint
    const content = {
      text: "", // No text provided for legacy image-only analysis
      imageUrl: imageUrl,
    };

    // Call the new unified endpoint logic
    req.body.blockId = blockId;
    req.body.content = content;
    req.body.userModified = false;

    // Forward to the unified handler
    return unifiedAnalyzeBlockHandler(req, res);
  } catch (error: any) {
    console.error(
      "/analyze-image error",
      error?.response?.data || error?.message || error,
    );
    res
      .status(500)
      .json({ error: "Internal server error", message: error?.message });
  }
});

// POST /api/ai/calories-popup-update - now integrates with unified analysis
router.post("/calories-popup-update", async (req: AuthRequest, res) => {
  try {
    const { text, calories, weight, entryId, blockId } = req.body;
    const userId = req.userId!;

    if (!text || !entryId || !blockId) {
      return res.status(400).json({
        error: "text, entryId, and blockId are required",
      });
    }

    if (!calories && !weight) {
      return res.status(400).json({
        error: "Either calories or weight must be provided",
      });
    }

    // Verify entry ownership
    const entry = await DiaryEntryModel.getById(entryId);
    if (!entry || entry.user_id !== userId) {
      return res.status(404).json({ error: "Entry not found" });
    }

    console.log(
      `[calories-popup-update] user=${userId} entry=${entryId} block=${blockId} calories=${calories} weight=${weight}`,
    );

    // Create block content structure for unified endpoint
    const userProvidedData: any = {};
    if (calories !== undefined) userProvidedData.calories = calories;
    if (weight !== undefined) userProvidedData.weight = weight;

    const content = {
      text: text,
      imageUrl: undefined, // No image in popup update
      userProvidedData: userProvidedData,
    };

    // Call the new unified endpoint logic
    req.body.blockId = blockId;
    req.body.content = content;
    req.body.userModified = true;

    // Forward to the unified handler
    return unifiedAnalyzeBlockHandler(req, res);
  } catch (error: any) {
    console.error(
      "/calories-popup-update error",
      error?.response?.data || error?.message || error,
    );
    res
      .status(500)
      .json({ error: "Internal server error", message: error?.message });
  }
});

export default router;
