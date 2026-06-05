import crypto from "crypto";
import Database from "../../services/database";
import { AIAnalysisCacheModel } from "../../models/AIAnalysisCache";
import { getNutritionProvider } from "./providers";
import { PromptContext } from "./prompts";
import { NutritionAnalysisResult, NutritionProvider } from "./providers/types";
import { CacheLookupService, CacheLookupResult } from "./cacheLookup";
import {
  normalize,
  extractQuantity,
  hashNormalized,
  normalizeForHash,
  findCanonicalForm,
} from "./normalization";

export class AIService {
  static async analyzeBlocks(blocks: any[]) {
    const provider = getNutritionProvider();
    const promptVersion = process.env.AI_PROMPT_VERSION || "v2";
    const temperature = Number(process.env.AI_TEMPERATURE ?? 0.2);
    const providerName = (process.env.AI_PROVIDER || "openai").toLowerCase();
    const model =
      providerName === "gemini"
        ? process.env.AI_GEMINI_MODEL || "gemini-2.5-flash"
        : process.env.AI_OPENAI_MODEL || "gpt-4o-mini";
    const concurrencyEnv = Number(process.env.AI_MAX_CONCURRENCY ?? 3);
    const concurrency =
      Number.isFinite(concurrencyEnv) && concurrencyEnv > 0
        ? concurrencyEnv
        : 3;

    const tasks = blocks.map(
      (block) => () =>
        AIService.analyzeSingleBlock(block, provider, {
          temperature,
          model,
          promptVersion,
        }),
    );

    return AIService.runWithConcurrency(tasks, concurrency);
  }

  static calculateTotals(blocks: any[]) {
    return blocks.reduce(
      (totals, block) => ({
        total_calories: totals.total_calories + (Number(block.calories) || 0),
        total_protein: totals.total_protein + (Number(block.protein) || 0),
        total_fat: totals.total_fat + (Number(block.fat) || 0),
        total_carbs: totals.total_carbs + (Number(block.carbs) || 0),
        total_fiber: totals.total_fiber + (Number(block.fiber) || 0),
        total_sugar: totals.total_sugar + (Number(block.sugar) || 0),
        total_sodium: totals.total_sodium + (Number(block.sodium) || 0),
      }),
      {
        total_calories: 0,
        total_protein: 0,
        total_fat: 0,
        total_carbs: 0,
        total_fiber: 0,
        total_sugar: 0,
        total_sodium: 0,
      },
    );
  }

  static hashContent(content: string): string {
    return crypto.createHash("sha256").update(content).digest("hex");
  }

  private static async runWithConcurrency<T>(
    tasks: Array<() => Promise<T>>,
    limit: number,
  ): Promise<T[]> {
    if (tasks.length === 0) {
      return [];
    }
    const results: T[] = new Array(tasks.length);
    const workerCount =
      Math.min(Math.max(1, Math.floor(limit) || 1), tasks.length) || 1;
    let nextIndex = 0;

    const workers = Array.from({ length: workerCount }, async () => {
      while (true) {
        const currentIndex = nextIndex++;
        if (currentIndex >= tasks.length) {
          break;
        }
        results[currentIndex] = await tasks[currentIndex]();
      }
    });

    await Promise.all(workers);
    return results;
  }

  private static async analyzeSingleBlock(
    block: any,
    provider: NutritionProvider,
    options: { temperature: number; model: string; promptVersion: string },
  ) {
    // If block was manually modified by the user, do not re-analyze.
    if (block.userModified) {
      return block;
    }

    const content = (block?.content || "").toString().trim();
    if (!content) {
      return block;
    }

    const imageUrl =
      typeof block?.imageUrl === "string" && block.imageUrl.trim()
        ? block.imageUrl.trim()
        : undefined;

    const promptContext: PromptContext | undefined = imageUrl
      ? {
          text: content,
          imageUrl,
          scenario: "multimodal",
        }
      : undefined;

    const hash = AIService.hashContent(content);

    // Smart cache lookup: try normalized + fuzzy match before LLM
    if (!imageUrl) {
      try {
        const cacheHit = await CacheLookupService.lookup(content, options.promptVersion);
        if (cacheHit) {
          return {
            ...block,
            ...cacheHit.analysis_result,
            confidence: cacheHit.confidence,
          };
        }
      } catch {
        // Smart cache failure is non-blocking, fall through to legacy + LLM
      }

      // Legacy exact content-hash lookup (backward compat)
      const cached = await AIAnalysisCacheModel.getByContentHash(hash, options.promptVersion);
      if (cached) {
        return {
          ...block,
          ...cached.analysis_result,
          confidence: cached.confidence,
        };
      }
    }

    try {
      const analysis: NutritionAnalysisResult = await provider.analyze(
        content,
        {
          temperature: options.temperature,
          model: options.model,
          promptVersion: options.promptVersion,
          imageUrl,
          context: promptContext,
        },
      );

      if (!imageUrl) {
        // Cache the PER-UNIT result for smart cache scaling
        const qty = extractQuantity(content);
        const normalizedContent = normalize(content);
        const canonicalBase = normalizeForHash(content);
        const normalizedHash = hashNormalized(canonicalBase);

        // Calculate per-unit values by dividing by quantity
        const perUnitCalories = qty.quantity > 0
          ? Number(analysis.calories) / qty.quantity
          : Number(analysis.calories);

        const perUnitResult = {
          ...analysis,
          calories: Math.round(perUnitCalories),
          protein: Math.round((Number(analysis.protein) || 0) / qty.quantity * 10) / 10,
          fat: Math.round((Number(analysis.fat) || 0) / qty.quantity * 10) / 10,
          carbs: Math.round((Number(analysis.carbs) || 0) / qty.quantity * 10) / 10,
          fiber: Math.round((Number(analysis.fiber) || 0) / qty.quantity * 10) / 10,
          sugar: Math.round((Number(analysis.sugar) || 0) / qty.quantity * 10) / 10,
          sodium: Math.round((Number(analysis.sodium) || 0) / qty.quantity * 10) / 10,
        };

        await AIAnalysisCacheModel.insert({
          contentHash: hash,
          content,
          analysisResult: perUnitResult,
          confidence: analysis.confidence || 0,
          rawResponseText: analysis.rawResponseText,
          providerModel: analysis.providerModel,
          temperature: analysis.temperature,
          promptVersion: analysis.promptVersion,
          parseOk: true,
          parseErrorText: null,
          attempt: "primary",
          usagePromptTokens: analysis.usage?.promptTokens,
          usageCompletionTokens: analysis.usage?.completionTokens,
          usageTotalTokens: analysis.usage?.totalTokens,
          normalizedContent,
          originalVariants: [content],
          hitCount: 0,
          source: 'llm',
          unitDescription: `${qty.quantity} ${qty.unit}`,
          unitCalories: perUnitCalories,
          normalizedHash,
        });
      }

      return {
        ...block,
        ...analysis,
      };
    } catch (error: any) {
      console.error("[AIService] analyzeSingleBlock failed", {
        message: error?.message,
      });
      return {
        ...block,
        calories: 0,
        protein: 0,
        fat: 0,
        carbs: 0,
        fiber: 0,
        sugar: 0,
        sodium: 0,
        confidence: 0,
      };
    }
  }
}
