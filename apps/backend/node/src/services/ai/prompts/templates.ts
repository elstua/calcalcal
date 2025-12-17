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

export interface PromptTemplate {
  name: string;
  build(context: PromptContext): string;
}

class BaseAnalysisPrompt implements PromptTemplate {
  name = 'base-analysis';

  build(context: PromptContext): string {
    const hasImage = !!context.imageUrl;
    const hasText = !!context.text;
    const hasUserData = !!context.userProvidedData;
    const isManualUpdate = context.scenario === 'manual-update';

    let prompt = `You are a nutrition expert. Analyze the provided food item and return ONLY a valid JSON object:\n`;
    prompt += `{\n`;
    prompt += `  "description": "<short food description>",\n`;
    prompt += `  "calories": <number>,\n`;
    prompt += `  "protein": <grams>,\n`;
    prompt += `  "fat": <grams>,\n`;
    prompt += `  "carbs": <grams>,\n`;
    prompt += `  "fiber": <grams>,\n`;
    prompt += `  "sugar": <grams>,\n`;
    prompt += `  "sodium": <mg>,\n`;
    prompt += `  "weight": <number in grams, optional but recommended>,\n`;
    prompt += `  "metric_description": <string with weight unit, e.g., "100 g", "1 cup", "1 serving">,\n`;
    prompt += `  "confidence": <0..1>\n`;
    prompt += `}\n`;

    // Add scenario-specific instructions
    if (hasImage && hasText) {
      prompt += `\nMultimodal Analysis Instructions:\n`;
      prompt += `- Analyze the food in the provided image\n`;
      prompt += `- Use the text description "${context.text}" as additional context\n`;
      prompt += `- Cross-reference the visual information with the textual description for accuracy\n`;
    } else if (hasImage && !hasText) {
      prompt += `\nImage-Only Analysis Instructions:\n`;
      prompt += `- Analyze the food item in the provided image\n`;
      prompt += `- Provide your best nutritional estimate based on visual cues\n`;
    } else if (!hasImage && hasText) {
      prompt += `\nText-Only Analysis Instructions:\n`;
      prompt += `- Analyze the food based on the description: "${context.text}"\n`;
      prompt += `- Use nutritional knowledge to estimate portion sizes and nutrients\n`;
    }

    // Add user data constraints
    if (hasUserData) {
      prompt += `\nUser-Provided Data Constraints:\n`;
      const constraints = [];
      if (context.userProvidedData!.calories !== undefined) {
        constraints.push(`Use exactly ${context.userProvidedData!.calories} calories`);
      }
      if (context.userProvidedData!.weight !== undefined) {
        constraints.push(`Use exactly ${context.userProvidedData!.weight}g weight`);
      }
      if (constraints.length > 0) {
        prompt += `- ${constraints.join(' and ')}\n`;
        if (context.userProvidedData!.calories !== undefined && context.userProvidedData!.weight !== undefined) {
          prompt += `- Adjust other macros proportionally to match the specified calories and weight\n`;
        } else if (context.userProvidedData!.calories !== undefined && context.userProvidedData!.weight === undefined) {
          prompt += `- Adjust other macros proportionally to match the specified calorie count\n`;
        } else if (context.userProvidedData!.calories === undefined && context.userProvidedData!.weight !== undefined) {
          prompt += `- Recalculate all nutrients based on the specified weight\n`;
        }
      }
    }

    // Add user modification handling
    if (isManualUpdate) {
      prompt += `\nManual Update Context:\n`;
      prompt += `- This is a user correction, prioritize accuracy over estimation\n`;
      prompt += `- The user has explicitly provided some values - treat them as ground truth\n`;
    }

    prompt += `\nIf uncertain, provide your best estimate. Always return valid JSON.`;

    return prompt.trim();
  }
}

class VoiceValidationPrompt implements PromptTemplate {
  name = 'voice-validation';

  build(context: PromptContext): string {
    const basePrompt = new BaseAnalysisPrompt().build(context);
    
    return `${basePrompt}

Voice-Specific Instructions:
- The text "${context.text}" may contain transcription errors or be imprecise
- Look for common speech-to-text issues (e.g., "gram" instead of "grams", numbers as words)
- Use context to clarify ambiguous measurements
- If the description seems incomplete or unclear, make reasonable assumptions based on typical food portions
- Prioritize practical, real-world nutritional values over literal interpretations`;
  }
}

class ManualUpdatePrompt implements PromptTemplate {
  name = 'manual-update';

  build(context: PromptContext): string {
    if (!context.userProvidedData) {
      throw new Error('Manual update requires user provided data');
    }

    const { calories, weight } = context.userProvidedData;
    const hasBoth = calories !== undefined && weight !== undefined;
    const hasCaloriesOnly = calories !== undefined && weight === undefined;
    const hasWeightOnly = calories === undefined && weight !== undefined;

    let prompt = `You are a nutrition expert. The user has updated nutritional information for a food item.\n\n`;
    
    if (context.text) {
      prompt += `Food description: "${context.text}"\n`;
    }
    
    if (context.imageUrl) {
      prompt += `[Image provided for visual reference]\n`;
    }

    prompt += `\nUser updates:\n`;
    if (calories !== undefined) {
      prompt += `- Calories: ${calories}kcal\n`;
    }
    if (weight !== undefined) {
      prompt += `- Weight: ${weight}g\n`;
    }

    prompt += `\nInstructions:\n`;

    if (hasBoth) {
      prompt += `- Use exactly ${calories} calories and ${weight}g weight as provided by the user\n`;
      prompt += `- Adjust other macros (protein, fat, carbs, fiber, sugar, sodium) proportionally to match these values\n`;
      prompt += `- Maintain realistic macro ratios for the food type\n`;
    } else if (hasCaloriesOnly) {
      prompt += `- Use exactly ${calories} calories as provided by the user\n`;
      prompt += `- Adjust other macros proportionally to match this calorie count\n`;
      prompt += `- Maintain reasonable weight estimate based on the food type and calorie density\n`;
    } else if (hasWeightOnly) {
      prompt += `- Use exactly ${weight}g weight as provided by the user\n`;
      prompt += `- Recalculate all nutritional values based on this weight\n`;
      prompt += `- Use standard nutritional data for the food type scaled to the specified weight\n`;
    }

    prompt += `\nReturn ONLY a valid JSON object:\n`;
    prompt += `{\n`;
    prompt += `  "description": "<food description>",\n`;
    prompt += `  "calories": <number>,\n`;
    prompt += `  "protein": <grams>,\n`;
    prompt += `  "fat": <grams>,\n`;
    prompt += `  "carbs": <grams>,\n`;
    prompt += `  "fiber": <grams>,\n`;
    prompt += `  "sugar": <grams>,\n`;
    prompt += `  "sodium": <mg>,\n`;
    prompt += `  "weight": <number in grams>,\n`;
    prompt += `  "metric_description": <string with weight unit>,\n`;
    prompt += `  "confidence": <0..1>\n`;
    prompt += `}\n`;

    prompt += `\nAlways return valid JSON with the specified values.`;

    return prompt.trim();
  }
}

export class PromptTemplateBuilder {
  private static templates: Map<string, PromptTemplate> = new Map([
    ['base-analysis', new BaseAnalysisPrompt()],
    ['voice-validation', new VoiceValidationPrompt()],
    ['manual-update', new ManualUpdatePrompt()],
  ]);

  static getTemplate(scenario: PromptContext['scenario']): PromptTemplate {
    const templateKey = scenario === 'manual-update' ? 'manual-update' : 
                       scenario === 'voice-validation' ? 'voice-validation' : 
                       'base-analysis';
    
    const template = this.templates.get(templateKey);
    if (!template) {
      throw new Error(`No template found for scenario: ${scenario}`);
    }
    return template;
  }

  static buildPrompt(context: PromptContext): string {
    const template = this.getTemplate(context.scenario);
    return template.build(context);
  }

  static addCustomTemplate(name: string, template: PromptTemplate): void {
    this.templates.set(name, template);
  }
}