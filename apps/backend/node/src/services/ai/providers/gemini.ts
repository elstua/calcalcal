import { loadPrompt } from '../prompt';
import { NutritionAnalysisResult, NutritionProvider } from './types';

type GoogleGenAIModule = typeof import('@google/genai/node');
type GoogleGenAIConstructor = GoogleGenAIModule['GoogleGenAI'];
type GoogleGenAIClient = InstanceType<GoogleGenAIConstructor>;

let googleGenAiModulePromise: Promise<GoogleGenAIModule> | null = null;

async function loadGoogleGenAiModule(): Promise<GoogleGenAIModule> {
  if (!googleGenAiModulePromise) {
    googleGenAiModulePromise = import('@google/genai/node');
  }
  return googleGenAiModulePromise;
}

async function createGeminiClient(apiKey: string): Promise<GoogleGenAIClient> {
  const { GoogleGenAI } = await loadGoogleGenAiModule();
  return new GoogleGenAI({ apiKey });
}

export class GeminiNutritionProvider implements NutritionProvider {
  private clientPromise: Promise<GoogleGenAIClient>;

  constructor() {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new Error('GEMINI_API_KEY is not configured');
    }
    this.clientPromise = createGeminiClient(apiKey);
  }

  private async getClient() {
    return this.clientPromise;
  }

  async analyze(
    content: string,
    options?: { temperature?: number; model?: string; prompt?: string; promptVersion?: string }
  ): Promise<NutritionAnalysisResult> {
    const model = options?.model || process.env.AI_GEMINI_MODEL || 'gemini-2.5-flash';
    const temperature = options?.temperature ?? Number(process.env.AI_TEMPERATURE ?? 0.2);
    const loaded = loadPrompt('nutrition');
    const systemPrompt = options?.prompt || loaded.text;
    const promptVersion = options?.promptVersion || loaded.version;
    const userPrompt = `${systemPrompt}\n\nFood description:\n${content}`;

    const client = await this.getClient();

    let responseText: string | undefined;
    let usage:
      | {
          promptTokenCount?: number | null;
          candidatesTokenCount?: number | null;
          totalTokenCount?: number | null;
        }
      | undefined;

    try {
      const response = await client.models.generateContent({
        model,
        contents: [
          {
            role: 'user',
            parts: [{ text: userPrompt }],
          },
        ],
        config: {
          temperature,
          responseMimeType: 'application/json',
        },
      });

      responseText = response.text?.trim();
      usage = response.usageMetadata;
    } catch (err: any) {
      const status = err?.status || err?.response?.status;
      const errData = err?.response?.data ?? err?.data ?? null;
      const safeData =
        typeof errData === 'string'
          ? errData
          : errData
          ? (() => {
              try {
                return JSON.stringify(errData);
              } catch {
                return '[unserializable error data]';
              }
            })()
          : null;
      console.error('[Gemini] models.generateContent failed', {
        model,
        temperature,
        status,
        message: err?.message,
        data: safeData,
      });
      throw new Error(err?.message || 'Gemini generateContent error');
    }

    if (!responseText) {
      console.error('[Gemini] Empty response', {
        model,
        temperature,
      });
      throw new Error('Empty response from Gemini');
    }

    let parsed: any = {};
    let parseOk = true;
    try {
      parsed = JSON.parse(responseText);
    } catch (_e) {
      parseOk = false;
    }

    if (!parseOk) {
      console.warn('[Gemini] Response parsing failed, returning zeros', {
        model,
        responseText,
      });
    }

    const result: NutritionAnalysisResult = {
      calories: Number(parsed?.calories || 0),
      protein: Number(parsed?.protein || 0),
      fat: Number(parsed?.fat || 0),
      carbs: Number(parsed?.carbs || 0),
      fiber: Number(parsed?.fiber || 0),
      sugar: Number(parsed?.sugar || 0),
      sodium: Number(parsed?.sodium || 0),
      confidence: Number(parsed?.confidence ?? 0.5),
      rawResponseText: responseText,
      usage: usage
        ? {
            promptTokens: usage.promptTokenCount ?? undefined,
            completionTokens: usage.candidatesTokenCount ?? undefined,
            totalTokens: usage.totalTokenCount ?? undefined,
          }
        : undefined,
      providerModel: model,
      temperature,
      promptVersion,
    };

    return result;
  }
}
