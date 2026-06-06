export interface PromptContext {
  text?: string;
  imageUrl?: string;
  userModified?: boolean;
  userProvidedData?: {
    calories?: number;
    weight?: number;
    protein?: number;
    fat?: number;
    carbs?: number;
    fiber?: number;
    sugar?: number;
    sodium?: number;
  };
  scenario: 'text-only' | 'image-only' | 'multimodal' | 'manual-update' | 'voice-validation';
}

export interface NutritionItem {
  name: string;
  source_text?: string;
  quantity?: number;
  calories: number;
  protein: number;
  fat: number;
  carbs: number;
  fiber: number;
  sugar: number;
  sodium: number;
  weight?: number;
  metric_description?: string;
  confidence?: number;
}

export interface NutritionAnalysisResult {
  calories: number;
  protein: number;
  fat: number;
  carbs: number;
  fiber: number;
  sugar: number;
  sodium: number;
  weight?: number;
  metric_description?: string;
  description?: string;
  confidence: number;
  items?: NutritionItem[];
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
  analyze(
    content: string,
    options?: {
      temperature?: number;
      model?: string;
      prompt?: string;
      promptVersion?: string;
      imageUrl?: string;
      context?: PromptContext;
    },
  ): Promise<NutritionAnalysisResult>;
}
