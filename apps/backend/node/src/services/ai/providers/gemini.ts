import { loadPrompt } from "../prompt/index";
import { NutritionAnalysisResult, NutritionProvider, PromptContext } from "./types";
import { PromptTemplateBuilder } from "../prompts";

type GoogleGenAIModule = typeof import("@google/genai");
type GoogleGenAIConstructor = GoogleGenAIModule["GoogleGenAI"];
type GoogleGenAIClient = InstanceType<GoogleGenAIConstructor>;

const dynamicImport = new Function(
  "specifier",
  "return import(specifier);",
) as <T>(specifier: string) => Promise<T>;

let googleGenAiClientPromise: Promise<GoogleGenAIClient> | null = null;

async function getGeminiClient(): Promise<GoogleGenAIClient> {
  if (!googleGenAiClientPromise) {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new Error("GEMINI_API_KEY is not configured");
    }

    googleGenAiClientPromise = dynamicImport<GoogleGenAIModule>(
      "@google/genai",
    ).then(({ GoogleGenAI }) => new GoogleGenAI({ apiKey }));
  }
  return googleGenAiClientPromise;
}

export class GeminiNutritionProvider implements NutritionProvider {
  private async getClient() {
    return getGeminiClient();
  }

  async analyze(
    content: string,
    options?: {
      temperature?: number;
      model?: string;
      prompt?: string;
      promptVersion?: string;
      imageUrl?: string;
      context?: PromptContext;
    },
  ): Promise<NutritionAnalysisResult> {
    const model =
      options?.model ||
      process.env.AI_MODEL ||
      process.env.AI_GEMINI_MODEL ||
      "gemini-2.5-flash";
    const temperature =
      options?.temperature ?? Number(process.env.AI_TEMPERATURE ?? 0.2);
    
    // Determine system prompt based on context or fallback to legacy
    let systemPrompt: string;
    let promptVersion: string;
    
    if (options?.context) {
      systemPrompt = options?.prompt || PromptTemplateBuilder.buildPrompt(options.context);
      promptVersion = options?.promptVersion || "unified-v1";
    } else {
      const loaded = loadPrompt("nutrition");
      systemPrompt = options?.prompt || loaded.text;
      promptVersion = options?.promptVersion || loaded.version;
    }
    
    const userPrompt = `${systemPrompt}\n\nFood description:\n${content}`;

    const client = await this.getClient();
    const timeoutEnv = Number(process.env.AI_PROVIDER_TIMEOUT_MS ?? 45000);
    const requestTimeout =
      Number.isFinite(timeoutEnv) && timeoutEnv > 0
        ? Math.floor(timeoutEnv)
        : undefined;

    let responseText: string | undefined;
    let usage:
      | {
          promptTokenCount?: number | null;
          candidatesTokenCount?: number | null;
          totalTokenCount?: number | null;
        }
      | undefined;

    // Build content parts based on whether we have an image
    const contentParts: any[] = [{ text: userPrompt }];
    
    if (options?.imageUrl) {
      // For Gemini, we'd need to handle image loading similar to OpenAI
      // For now, we'll just note that image processing is supported
      console.warn("[GeminiNutritionProvider] Image support not yet fully implemented for Gemini provider");
    }

    try {
      const response = await client.models.generateContent({
        model,
        contents: [
          {
            role: "user",
            parts: contentParts,
          },
        ],
        config: {
          temperature,
          responseMimeType: "application/json",
          ...(requestTimeout
            ? {
                httpOptions: {
                  timeout: requestTimeout,
                },
              }
            : {}),
        },
      });

      responseText = response.text?.trim();
      usage = response.usageMetadata;
    } catch (err: any) {
      const status = err?.status || err?.response?.status;
      const errData = err?.response?.data ?? err?.data ?? null;
      const safeData =
        typeof errData === "string"
          ? errData
          : errData
            ? (() => {
                try {
                  return JSON.stringify(errData);
                } catch {
                  return "[unserializable error data]";
                }
              })()
            : null;
      console.error("[Gemini] models.generateContent failed", {
        model,
        temperature,
        status,
        message: err?.message,
        data: safeData,
      });
      throw new Error(err?.message || "Gemini generateContent error");
    }

    if (!responseText) {
      console.error("[Gemini] Empty response", {
        model,
        temperature,
      });
      throw new Error("Empty response from Gemini");
    }

    let parsed: any = {};
    let parseOk = true;
    try {
      parsed = JSON.parse(responseText);
    } catch (_e) {
      parseOk = false;
    }

    if (!parseOk) {
      console.warn("[Gemini] Response parsing failed, returning zeros", {
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
      weight: parsed?.weight ? Number(parsed?.weight) : undefined,
      metric_description: parsed?.metric_description || undefined,
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
