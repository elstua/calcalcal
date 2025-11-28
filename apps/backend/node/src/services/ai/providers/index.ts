import { NutritionProvider } from './types';
import { OpenAINutritionProvider } from './openai';
import { GeminiNutritionProvider } from './gemini';

export function getNutritionProvider(): NutritionProvider {
  const provider = (process.env.AI_PROVIDER || 'openai').toLowerCase();
  switch (provider) {
    case 'gemini':
      return new GeminiNutritionProvider();
    case 'openai':
    default:
      return new OpenAINutritionProvider();
  }
}


