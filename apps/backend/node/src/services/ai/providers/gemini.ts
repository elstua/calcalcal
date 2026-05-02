import { loadPrompt } from "../prompt/index";
import { NutritionAnalysisResult, NutritionProvider, PromptContext } from "./types";
import { PromptTemplateBuilder } from "../prompts";
import fs from "fs";
import path from "path";

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

  /**
   * Prepares an image for Gemini by converting local URLs to base64 inlineData
   * Returns an object with mimeType and data for Gemini's inlineData format
   */
  private async prepareImageForGemini(imageUrl: string): Promise<{ mimeType: string; data: string } | undefined> {
    try {
      // Handle relative paths like /uploads/... directly (common from iOS app)
      if (imageUrl.startsWith("/uploads/")) {
        const uploadsDir = path.resolve(
          process.cwd(),
          "apps",
          "backend",
          "node",
          "uploads",
        );
        const relative = imageUrl.replace(/^\/uploads\//, "");
        const filePath = path.resolve(uploadsDir, relative);

        console.log("[GeminiNutritionProvider] Attempting to read local file:", filePath);

        if (fs.existsSync(filePath)) {
          const buf = fs.readFileSync(filePath);
          const ext = path.extname(filePath).toLowerCase();
          const mimeType =
            ext === ".png"
              ? "image/png"
              : ext === ".webp"
                ? "image/webp"
                : "image/jpeg";
          const base64Data = buf.toString("base64");
          console.log("[GeminiNutritionProvider] Converted local image to base64 inlineData, size:", buf.length, "bytes");
          return { mimeType, data: base64Data };
        } else {
          console.warn("[GeminiNutritionProvider] Local file not found for", filePath);
        }
        return undefined;
      }

      // Try parsing as URL for localhost or remote URLs
      const u = new URL(imageUrl);
      const isLocalHost =
        u.hostname === "localhost" || u.hostname === "127.0.0.1";

      if (isLocalHost && u.pathname.startsWith("/uploads/")) {
        const uploadsDir = path.resolve(
          process.cwd(),
          "apps",
          "backend",
          "node",
          "uploads",
        );
        const relative = u.pathname.replace(/^\/uploads\//, "");
        const filePath = path.resolve(uploadsDir, relative);

        console.log("[GeminiNutritionProvider] Attempting to read local file from URL:", filePath);

        if (fs.existsSync(filePath)) {
          const buf = fs.readFileSync(filePath);
          const ext = path.extname(filePath).toLowerCase();
          const mimeType =
            ext === ".png"
              ? "image/png"
              : ext === ".webp"
                ? "image/webp"
                : "image/jpeg";
          const base64Data = buf.toString("base64");
          console.log("[GeminiNutritionProvider] Converted local image to base64 inlineData, size:", buf.length, "bytes");
          return { mimeType, data: base64Data };
        } else {
          console.warn("[GeminiNutritionProvider] Local file not found for", filePath);
        }
      }

      // For remote URLs, fetch the image and convert to base64
      try {
        console.log("[GeminiNutritionProvider] Fetching remote image:", imageUrl);
        const response = await fetch(imageUrl);
        if (response.ok) {
          const arrayBuffer = await response.arrayBuffer();
          const buf = Buffer.from(arrayBuffer);
          const contentType = response.headers.get("content-type") || "image/jpeg";
          const mimeType = contentType.split(";")[0].trim();
          const base64Data = buf.toString("base64");
          console.log("[GeminiNutritionProvider] Fetched remote image and converted to base64 inlineData, size:", buf.length, "bytes");
          return { mimeType, data: base64Data };
        } else {
          console.warn("[GeminiNutritionProvider] Failed to fetch remote image:", response.status);
        }
      } catch (fetchErr) {
        console.warn("[GeminiNutritionProvider] Error fetching remote image:", fetchErr);
      }

      return undefined;
    } catch (_e) {
      // Not a valid URL and not a relative path we can handle
      console.warn("[GeminiNutritionProvider] Could not process image URL:", imageUrl);
      return undefined;
    }
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
    const contentParts: any[] = [];

    // Add text content
    if (options?.imageUrl) {
      // For multimodal, use a cleaner prompt structure
      const textPrompt = content && content.trim()
        ? `${systemPrompt}\n\nAnalyze this food: ${content}`
        : `${systemPrompt}\n\nAnalyze the food shown in this image and return JSON as specified.`;
      contentParts.push({ text: textPrompt });
    } else {
      const userPrompt = `${systemPrompt}\n\nFood description:\n${content}`;
      contentParts.push({ text: userPrompt });
    }

    // Handle image if provided
    if (options?.imageUrl) {
      const imageData = await this.prepareImageForGemini(options.imageUrl);
      if (imageData) {
        contentParts.push({
          inlineData: {
            mimeType: imageData.mimeType,
            data: imageData.data,
          },
        });
        console.log("[GeminiNutritionProvider] Added image to content parts");
      } else {
        console.warn("[GeminiNutritionProvider] Could not prepare image for analysis, proceeding with text only");
      }
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
      description: parsed?.description || undefined,
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
