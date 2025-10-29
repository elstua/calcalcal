import { OpenAI } from 'openai';
import { NutritionAnalysisResult, NutritionProvider } from './types';
import { loadPrompt } from '../prompt';

const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

export class OpenAINutritionProvider implements NutritionProvider {
  async analyze(
    content: string,
    options?: { temperature?: number; model?: string; prompt?: string; promptVersion?: string }
  ): Promise<NutritionAnalysisResult> {
    const model = options?.model || process.env.AI_OPENAI_MODEL || 'gpt-4o-mini';
    const temperature = options?.temperature ?? Number(process.env.AI_TEMPERATURE ?? 0.2);
    const loaded = loadPrompt('nutrition');
    const systemPrompt = options?.prompt || loaded.text;
    const promptVersion = options?.promptVersion || loaded.version;

    const completion = await client.chat.completions.create({
      model,
      temperature,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: `Analyze this food: ${content}` },
      ],
    });

    const responseText = completion.choices[0]?.message?.content?.trim();
    if (!responseText) {
      throw new Error('Empty response from OpenAI');
    }

    let parsed: any;
    let parseOk = true;
    try {
      parsed = JSON.parse(responseText);
    } catch (_e) {
      parseOk = false;
      // Fallback: try to extract JSON-ish object
      parsed = {};
    }

    const result: NutritionAnalysisResult = {
      calories: Number(parsed.calories || 0),
      protein: Number(parsed.protein || 0),
      fat: Number(parsed.fat || 0),
      carbs: Number(parsed.carbs || 0),
      fiber: Number(parsed.fiber || 0),
      sugar: Number(parsed.sugar || 0),
      sodium: Number(parsed.sodium || 0),
      confidence: Number(parsed.confidence ?? 0.5),
      rawResponseText: responseText,
      usage: {
        promptTokens: completion.usage?.prompt_tokens,
        completionTokens: completion.usage?.completion_tokens,
        totalTokens: completion.usage?.total_tokens,
      },
      providerModel: model,
      temperature,
      promptVersion,
    };

    return result;
  }
}

const defaultSystemPrompt = `You are a nutrition expert. Analyze the food description and return ONLY a valid JSON object with these exact fields (all numbers):
{
  "calories": <number>,
  "protein": <number in grams>,
  "fat": <number in grams>,
  "carbs": <number in grams>,
  "fiber": <number in grams>,
  "sugar": <number in grams>,
  "sodium": <number in mg>,
  "confidence": <number between 0 and 1>
}

If you cannot determine the nutrition, use your best estimate. Always return valid JSON.`;


