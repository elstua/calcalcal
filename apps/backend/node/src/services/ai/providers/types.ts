export interface NutritionAnalysisResult {
  calories: number;
  protein: number;
  fat: number;
  carbs: number;
  fiber: number;
  sugar: number;
  sodium: number;
  confidence: number;
  // Optional usage/metadata for caching/observability
  rawResponseText?: string;
  usage?: {
    promptTokens?: number;
    completionTokens?: number;
    totalTokens?: number;
  };
  providerModel?: string;
  temperature?: number;
  promptVersion?: string;
}

export interface NutritionProvider {
  analyze(content: string, options?: { temperature?: number; model?: string; prompt?: string; promptVersion?: string }): Promise<NutritionAnalysisResult>;
}


