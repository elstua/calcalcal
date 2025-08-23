import type { ChatMessage } from "./types.ts"

// Edit this schema text to change the expected JSON output fields and rules
export const ANALYSIS_SCHEMA_TEXT = `Schema (JSON object):
{
  "calories": number,              // >= 0
  "protein": number,               // grams >= 0
  "fat": number,                   // grams >= 0
  "carbs": number,                 // grams >= 0
  "fiber": number,                 // grams >= 0
  "sugar": number,                 // grams >= 0
  "sodium": number,                // milligrams >= 0
  "confidence": number,            // 0..1
  "food_name": string?,            // optional
  "serving": { "quantity": number, "unit": "piece|g|ml|serving" }? // optional
}
Rules:
- Use grams for macros; milligrams for sodium
- Assume common portion sizes if unspecified; avoid unrealistic values
- Return ONLY a valid JSON object (no markdown/code fences/prose)`

export function buildPrimaryPrompt(content: string): ChatMessage[] {
  return [
    {
      role: "system",
      content:
        `You are a nutrition expert. Analyze the food description and return JSON matching the schema below. Return ONLY JSON.\n\n${ANALYSIS_SCHEMA_TEXT}`,
    },
    { role: "user", content },
  ]
}

export function buildRetryPrompt(content: string): ChatMessage[] {
  return [
    {
      role: "system",
      content:
        `Return ONLY a valid JSON object that matches the schema. No prose, no markdown, no code fences.\n\n${ANALYSIS_SCHEMA_TEXT}`,
    },
    { role: "user", content },
  ]
}


