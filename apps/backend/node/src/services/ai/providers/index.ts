import { NutritionProvider } from './types';
import { OpenAINutritionProvider } from './openai';

export function getNutritionProvider(): NutritionProvider {
  const provider = (process.env.AI_PROVIDER || 'openai').toLowerCase();
  switch (provider) {
    case 'openai':
    default:
      return new OpenAINutritionProvider();
  }
}


