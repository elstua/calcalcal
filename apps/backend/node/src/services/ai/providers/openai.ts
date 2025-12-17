import { OpenAI } from "openai";
import { NutritionAnalysisResult, NutritionProvider, PromptContext } from "./types";
import { loadPrompt } from "../prompt";
import { PromptTemplateBuilder } from "../prompts";
import fs from "fs";
import path from "path";

// Create OpenAI client with default timeout
const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
  timeout: Number(process.env.AI_PROVIDER_TIMEOUT_MS ?? 45_000),
});

export class OpenAINutritionProvider implements NutritionProvider {
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
      process.env.AI_OPENAI_MODEL ||
      "gpt-4o-mini";
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

    // Get timeout from options or environment
    const timeoutEnv = Number(process.env.AI_PROVIDER_TIMEOUT_MS ?? 45_000);
    const timeout =
      Number.isFinite(timeoutEnv) && timeoutEnv > 0
        ? Math.floor(timeoutEnv)
        : 45_000;

    // Handle image if provided
    let imageForOpenAI: string | undefined;
    if (options?.imageUrl) {
      imageForOpenAI = await this.prepareImageForOpenAI(options.imageUrl);
    }

    let completion;
    try {
      const messages: any[] = [
        { role: "system", content: systemPrompt }
      ];

      // Build user message based on content type
      if (imageForOpenAI) {
        // Multimodal message with both image and text
        const userContent: any[] = [];
        
        if (content && content.trim()) {
          userContent.push({
            type: "text",
            text: options?.context?.scenario === 'image-only' 
              ? "Analyze this food photo and return JSON as specified."
              : `Analyze this food: ${content}`
          });
        } else {
          userContent.push({
            type: "text", 
            text: "Analyze this food photo and return JSON as specified."
          });
        }
        
        userContent.push({
          type: "image_url",
          image_url: { url: imageForOpenAI }
        });
        
        messages.push({
          role: "user",
          content: userContent
        });
      } else {
        // Text-only message
        messages.push({
          role: "user",
          content: `Analyze this food: ${content}`
        });
      }

      completion = await client.chat.completions.create({
        model,
        temperature,
        max_tokens: 1000, // Limit tokens to prevent long responses
        messages,
      });
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
      console.error("[OpenAI] chat.completions.create failed", {
        model,
        temperature,
        status,
        message: err?.message,
        data: safeData,
      });
      throw new Error(err?.message || "OpenAI chat.completions error");
    }

    const responseText = completion.choices[0]?.message?.content?.trim();
    if (!responseText) {
      console.error("[OpenAI] Empty response", {
        model,
        temperature,
        choices: completion.choices?.length,
        usage: completion.usage,
      });
      throw new Error("Empty response from OpenAI");
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
      weight: parsed.weight ? Number(parsed.weight) : undefined,
      metric_description: parsed.metric_description || undefined,
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

  private async prepareImageForOpenAI(imageUrl: string): Promise<string | undefined> {
    try {
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
        
        if (fs.existsSync(filePath)) {
          const buf = fs.readFileSync(filePath);
          const ext = path.extname(filePath).toLowerCase();
          const mime =
            ext === ".png"
              ? "image/png"
              : ext === ".webp"
                ? "image/webp"
                : "image/jpeg";
          const dataUrl = `data:${mime};base64,${buf.toString("base64")}`;
          console.log("[OpenAINutritionProvider] Inlined local image as data URL");
          return dataUrl;
        } else {
          console.warn("[OpenAINutritionProvider] Local file not found for", filePath);
        }
      }
      
      // Return original URL if not local or no conversion needed
      return imageUrl;
    } catch (_e) {
      // Not a valid URL; return as-is
      return imageUrl;
    }
  }
}

const defaultSystemPrompt = `Analyze the food description from the nutrition point of view and return ONLY a valid JSON object with these exact fields:
{
  "calories": <number>,
  "protein": <number in grams>,
  "fat": <number in grams>,
  "carbs": <number in grams>,
  "fiber": <number in grams>,
  "sugar": <number in grams>,
  "sodium": <number in mg>,
  "weight": <number in grams, optional but recommended>,
  "metric_description": <string with weight unit, e.g., "100 g", "1 cup", "1 serving">,
  "confidence": <number between 0 and 1>
}

If you cannot determine the nutrition, use your best estimate. If the food description is not clear or very broad, like "dinner/breakfast/my lunch" without any specific description, return null. Try to split complex dishes into main ingredients and the way they are cooked, it will help you to get the correct nutrition. Always return valid JSON.`;
