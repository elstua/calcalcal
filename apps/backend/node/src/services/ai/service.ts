import crypto from 'crypto';
import Database from '../../services/database';
import { AIAnalysisCacheModel } from '../../models/AIAnalysisCache';
import { getNutritionProvider } from './providers';
import { NutritionAnalysisResult } from './providers/types';

export class AIService {
  static async analyzeBlocks(blocks: any[]) {
    const provider = getNutritionProvider();
    const promptVersion = process.env.AI_PROMPT_VERSION || 'v1';
    const temperature = Number(process.env.AI_TEMPERATURE ?? 0.2);
    const model = process.env.AI_OPENAI_MODEL || 'gpt-4o-mini';

    const results: any[] = [];

    for (const block of blocks) {
      const content = (block?.content || '').toString().trim();
      if (!content) {
        results.push(block);
        continue;
      }

      const hash = AIService.hashContent(content);

      const cached = await AIAnalysisCacheModel.getByContentHash(hash);
      if (cached) {
        results.push({
          ...block,
          ...cached.analysis_result,
          confidence: cached.confidence,
        });
        continue;
      }

      try {
        const analysis: NutritionAnalysisResult = await provider.analyze(content, {
          temperature,
          model,
          promptVersion,
        });

        await AIAnalysisCacheModel.insert({
          contentHash: hash,
          content,
          analysisResult: analysis,
          confidence: analysis.confidence || 0,
          rawResponseText: analysis.rawResponseText,
          providerModel: analysis.providerModel,
          temperature: analysis.temperature,
          promptVersion: analysis.promptVersion,
          parseOk: true,
          parseErrorText: null,
          attempt: 'primary',
          usagePromptTokens: analysis.usage?.promptTokens,
          usageCompletionTokens: analysis.usage?.completionTokens,
          usageTotalTokens: analysis.usage?.totalTokens,
        });

        results.push({
          ...block,
          ...analysis,
        });
      } catch (error) {
        results.push({
          ...block,
          calories: 0,
          protein: 0,
          fat: 0,
          carbs: 0,
          fiber: 0,
          sugar: 0,
          sodium: 0,
          confidence: 0,
        });
      }
    }

    return results;
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
      }
    );
  }

  static hashContent(content: string): string {
    return crypto.createHash('sha256').update(content).digest('hex');
  }
}


