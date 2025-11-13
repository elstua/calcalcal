import fs from 'fs';
import path from 'path';

export function loadPrompt(name: string): { text: string; version: string } {
  const version = process.env.AI_PROMPT_VERSION || 'v1';
  const fileName = `${name}_${version}.txt`;
  const filePath = path.join(__dirname, `${fileName}`);
  try {
    const text = fs.readFileSync(filePath, 'utf8');
    return { text, version };
  } catch (_e) {
    // Fallback to v1 inline
    const text = `Analyze the selected food description and return ONLY a valid JSON object with these exact fields (all numbers):\n{\n  "calories": <number>,\n  "protein": <number in grams>,\n  "fat": <number in grams>,\n  "carbs": <number in grams>,\n  "fiber": <number in grams>,\n  "sugar": <number in grams>,\n  "sodium": <number in mg>,\n  "confidence": <number between 0 and 1>\n}\n\nIf you cannot determine the nutrition, use your best estimate. If the food description is not clear or very broad, like "dinner/breakfast/my lunch" without any specific description, return null. Try to split complex dishes into main ingredients and the way they are cooked, it will help you to get the correct nutrition. Always return valid JSON.`;
    return { text, version: 'v1' };
  }
}


