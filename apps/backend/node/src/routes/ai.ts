import { Router } from "express";
import { AuthRequest, authenticateToken } from "../middleware/auth";
import { DiaryEntryModel } from "../models/DiaryEntry";
import { AIService } from "../services/ai/service";
import Database from "../services/database";
import { OpenAI } from "openai";
import fs from "fs";
import path from "path";

const router = Router();

router.use(authenticateToken);

const activeAnalysisJobs = new Map<string, symbol>();

function cloneBlocks(blocks: any[]): any[] {
  try {
    return JSON.parse(JSON.stringify(blocks));
  } catch (_err) {
    // Fallback shallow copy
    return blocks.map((block) => ({ ...block }));
  }
}

function queueAnalysisJob(entryId: string, blocks: any[]) {
  const jobToken = Symbol(entryId);
  const safeBlocks = cloneBlocks(blocks);
  activeAnalysisJobs.set(entryId, jobToken);

  setImmediate(async () => {
    console.log(
      `[ai:analyze] job start entry=${entryId} blocks=${safeBlocks.length}`,
    );
    try {
      const analyzedBlocks = await AIService.analyzeBlocks(safeBlocks);
      const totals = AIService.calculateTotals(analyzedBlocks);

      const isLatest = activeAnalysisJobs.get(entryId) === jobToken;
      if (!isLatest) {
        console.warn(`[ai:analyze] stale job skipped entry=${entryId}`);
        return;
      }

      await Database.query(
        `UPDATE diary_entries SET
           blocks = $1,
           total_calories = $2,
           total_protein = $3,
           total_fat = $4,
           total_carbs = $5,
           total_fiber = $6,
           total_sugar = $7,
           total_sodium = $8,
           ai_analysis_status = $9,
           ai_analysis_error = NULL
         WHERE id = $10`,
        [
          JSON.stringify(analyzedBlocks),
          totals.total_calories,
          totals.total_protein,
          totals.total_fat,
          totals.total_carbs,
          totals.total_fiber,
          totals.total_sugar,
          totals.total_sodium,
          "completed",
          entryId,
        ],
      );
      console.log(`[ai:analyze] job completed entry=${entryId}`);
    } catch (error: any) {
      const isLatest = activeAnalysisJobs.get(entryId) === jobToken;
      if (!isLatest) {
        console.warn(
          `[ai:analyze] stale job failed but ignored entry=${entryId}`,
        );
        return;
      }

      console.error("[ai:analyze] job failed", {
        entryId,
        message: error?.message,
      });
      await Database.query(
        `UPDATE diary_entries SET ai_analysis_status = $1, ai_analysis_error = $2 WHERE id = $3`,
        ["failed", error?.message || "Unknown error", entryId],
      );
    } finally {
      if (activeAnalysisJobs.get(entryId) === jobToken) {
        activeAnalysisJobs.delete(entryId);
      }
    }
  });
}

// POST /api/ai/analyze
router.post("/analyze", async (req: AuthRequest, res) => {
  try {
    const { entryId, blocks } = req.body;
    const userId = req.userId!;

    if (!entryId || !Array.isArray(blocks)) {
      return res.status(400).json({
        error: "entryId and blocks array are required",
      });
    }

    const entry = await DiaryEntryModel.getById(entryId);
    if (!entry || entry.user_id !== userId) {
      return res.status(404).json({ error: "Entry not found" });
    }

    await Database.query(
      `UPDATE diary_entries SET ai_analysis_status = $1, ai_analysis_error = NULL WHERE id = $2`,
      ["processing", entryId],
    );

    queueAnalysisJob(entryId, blocks);

    return res
      .status(202)
      .json({ success: true, status: "processing", updatedBlocksCount: null });
  } catch (error) {
    res.status(500).json({ error: "Internal server error" });
  }
});

// POST /api/ai/analyze-image
router.post("/analyze-image", async (req: AuthRequest, res) => {
  try {
    const { imageUrl, entryId, blockId } = req.body || {};
    const userId = req.userId!;

    if (!imageUrl || typeof imageUrl !== "string") {
      return res.status(400).json({ error: "imageUrl is required" });
    }

    // Debug: Log full imageUrl to detect trailing characters
    console.log(`[analyze-image] FULL imageUrl received: "${imageUrl}"`);
    console.log(
      `[analyze-image] imageUrl length: ${imageUrl.length}, last 10 chars: "${imageUrl.slice(-10)}"`,
    );

    // Check for and fix trailing dot after file extension (defensive fix for URL corruption)
    let cleanedImageUrl = imageUrl;
    const trailingDotPattern = /\.(jpg|jpeg|png|webp|gif)\.$/i;
    if (trailingDotPattern.test(cleanedImageUrl)) {
      console.warn(
        "[analyze-image] ⚠️ WARNING: imageUrl ends with trailing dot after extension, stripping it",
      );
      cleanedImageUrl = cleanedImageUrl.slice(0, -1);
      console.log(`[analyze-image] Cleaned imageUrl: "${cleanedImageUrl}"`);
    } else if (imageUrl.endsWith(".")) {
      console.warn(
        "[analyze-image] ⚠️ WARNING: imageUrl ends with a trailing dot (but not after known extension)",
      );
    }

    if (!process.env.OPENAI_API_KEY) {
      console.error("[analyze-image] Missing OPENAI_API_KEY");
      return res.status(500).json({ error: "AI provider not configured" });
    }

    // Optional: verify entry ownership if provided
    if (entryId) {
      const entry = await DiaryEntryModel.getById(entryId);
      if (!entry || entry.user_id !== userId) {
        return res.status(404).json({ error: "Entry not found" });
      }
    }

    // Analyze with OpenAI multimodal (one pass: description + macros)
    const client = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
      timeout: 45_000,
    });
    const model = process.env.AI_OPENAI_MODEL || "gpt-4o-mini";
    const temperature = Number(process.env.AI_TEMPERATURE ?? 0.2);

    console.log(
      `[analyze-image] user=${userId} model=${model} url=${cleanedImageUrl.slice(0, 120)}${
        cleanedImageUrl.length > 120 ? "…" : ""
      }`,
    );

    const systemPrompt = `
You are a nutrition expert. Look at the image and return ONLY a valid JSON object:
{
  "description": "<short food description>",
  "calories": <number>,
  "protein": <grams>,
  "fat": <grams>,
  "carbs": <grams>,
  "fiber": <grams>,
  "sugar": <grams>,
  "sodium": <mg>,
  "confidence": <0..1>
}
If uncertain, provide your best estimate. Always return valid JSON.
`.trim();

    console.time("[analyze-image] openai_call");
    // If the image is hosted on localhost, OpenAI cannot fetch it.
    // Inline it as a data URL by reading from the local uploads directory.
    let imageForOpenAI: string = cleanedImageUrl;
    try {
      const u = new URL(cleanedImageUrl);
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
          imageForOpenAI = dataUrl;
          console.log("[analyze-image] Inlined local image as data URL");
        } else {
          console.warn("[analyze-image] Local file not found for", filePath);
        }
      }
    } catch (_e) {
      // Not a valid URL; ignore and use as-is
    }

    const completion = await client.chat.completions.create({
      model,
      temperature,
      messages: [
        { role: "system", content: systemPrompt },
        {
          role: "user",
          content: [
            {
              type: "text",
              text: "Analyze this food photo and return JSON as specified.",
            },
            { type: "image_url", image_url: { url: imageForOpenAI } },
          ] as any,
        },
      ],
    });
    console.timeEnd("[analyze-image] openai_call");

    const responseText = completion.choices[0]?.message?.content?.trim();
    if (!responseText) {
      console.error("[analyze-image] Empty response from AI provider");
      return res.status(500).json({ error: "Empty response from AI provider" });
    }

    let parsed: any;
    try {
      parsed = JSON.parse(responseText);
    } catch {
      // If not pure JSON, try to extract JSON block (best-effort)
      const match = responseText.match(/\{[\s\S]*\}/);
      if (match) {
        try {
          parsed = JSON.parse(match[0]);
        } catch {
          parsed = undefined;
        }
      }
    }
    if (!parsed || typeof parsed !== "object") {
      console.error(
        "[analyze-image] Failed to parse AI response:",
        responseText,
      );
      return res
        .status(500)
        .json({ error: "Failed to parse AI response", message: responseText });
    }

    // Normalize and coerce to numbers
    const result = {
      description: String(parsed.description ?? "").slice(0, 200),
      calories: Number(parsed.calories ?? 0),
      macros: {
        protein: Number(parsed.protein ?? 0),
        fat: Number(parsed.fat ?? 0),
        carbs: Number(parsed.carbs ?? 0),
        fiber: Number(parsed.fiber ?? 0),
        sugar: Number(parsed.sugar ?? 0),
        sodium: Number(parsed.sodium ?? 0),
      },
      confidence: Number(parsed.confidence ?? 0.5),
    };

    console.log(
      `[analyze-image] success calories=${result.calories} protein=${result.macros.protein} fat=${result.macros.fat} carbs=${result.macros.carbs}`,
    );
    // v1: client merges into the block and totals
    // (optional future: server-side merge into db when entryId/blockId are provided)
    res.json(result);
  } catch (error: any) {
    console.error(
      "/analyze-image error",
      error?.response?.data || error?.message || error,
    );
    res
      .status(500)
      .json({ error: "Internal server error", message: error?.message });
  }
});

// POST /api/ai/calories-popup-update
router.post("/calories-popup-update", async (req: AuthRequest, res) => {
  try {
    const { text, calories, weight, entryId, blockId } = req.body;
    const userId = req.userId!;

    if (!text || !entryId || !blockId) {
      return res.status(400).json({
        error: "text, entryId, and blockId are required",
      });
    }

    if (!calories && !weight) {
      return res.status(400).json({
        error: "Either calories or weight must be provided",
      });
    }

    // Verify entry ownership
    const entry = await DiaryEntryModel.getById(entryId);
    if (!entry || entry.user_id !== userId) {
      return res.status(404).json({ error: "Entry not found" });
    }

    console.log(
      `[calories-popup-update] user=${userId} entry=${entryId} block=${blockId} calories=${calories} weight=${weight}`,
    );

    if (!process.env.OPENAI_API_KEY) {
      console.error("[calories-popup-update] Missing OPENAI_API_KEY");
      return res.status(500).json({ error: "AI provider not configured" });
    }

    const client = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
      timeout: 45_000,
    });
    const model = process.env.AI_OPENAI_MODEL || "gpt-4o-mini";
    const temperature = Number(process.env.AI_TEMPERATURE ?? 0.2);

    // Build prompt based on what user changed
    let prompt = "";
    if (weight && !calories) {
      // User changed weight, recalculate calories
      prompt = `
You are a nutrition expert. The user has updated the weight of a food item.

Original food description: "${text}"
New weight: ${weight}g

Please analyze this food and return ONLY a valid JSON object with updated nutritional information:
{
  "calories": <number>,
  "protein": <grams>,
  "fat": <grams>,
  "carbs": <grams>,
  "fiber": <grams>,
  "sugar": <grams>,
  "sodium": <mg>,
  "confidence": <0..1>
}

Base the calculation on the new weight of ${weight}g. If uncertain, provide your best estimate. Always return valid JSON.
`.trim();
    } else if (calories && weight) {
      // User changed both calories and weight
      prompt = `
You are a nutrition expert. The user has updated both the calories and weight of a food item.

Original food description: "${text}"
New calories: ${calories}kcal
New weight: ${weight}g

Please analyze this food and return ONLY a valid JSON object with updated nutritional information:
{
  "calories": <number>,
  "protein": <grams>,
  "fat": <grams>,
  "carbs": <grams>,
  "fiber": <grams>,
  "sugar": <grams>,
  "sodium": <mg>,
  "confidence": <0..1>
}

Use the provided values of ${calories} calories and ${weight}g weight. Adjust other macros proportionally. Always return valid JSON.
`.trim();
    } else if (calories && !weight) {
      // User changed calories only, adjust macros proportionally
      prompt = `
You are a nutrition expert. The user has updated the calories of a food item while keeping the same weight.

Original food description: "${text}"
New calories: ${calories}kcal

Please analyze this food and return ONLY a valid JSON object with updated nutritional information:
{
  "calories": <number>,
  "protein": <grams>,
  "fat": <grams>,
  "carbs": <grams>,
  "fiber": <grams>,
  "sugar": <grams>,
  "sodium": <mg>,
  "confidence": <0..1>
}

Use exactly ${calories} calories and adjust other macros proportionally to match this calorie count. Always return valid JSON.
`.trim();
    } else {
      return res.status(400).json({
        error: "Invalid combination of calories and weight",
      });
    }

    console.time("[calories-popup-update] openai_call");
    const completion = await client.chat.completions.create({
      model,
      temperature,
      messages: [
        { role: "system", content: prompt },
        {
          role: "user",
          content: `Analyze this food and return JSON as specified: ${text}`,
        },
      ],
    });
    console.timeEnd("[calories-popup-update] openai_call");

    const responseText = completion.choices[0]?.message?.content?.trim();
    if (!responseText) {
      console.error("[calories-popup-update] Empty response from AI provider");
      return res.status(500).json({ error: "Empty response from AI provider" });
    }

    let parsed: any;
    try {
      parsed = JSON.parse(responseText);
    } catch {
      // If not pure JSON, try to extract JSON block (best-effort)
      const match = responseText.match(/\{[\s\S]*\}/);
      if (match) {
        try {
          parsed = JSON.parse(match[0]);
        } catch {
          parsed = undefined;
        }
      }
    }
    if (!parsed || typeof parsed !== "object") {
      console.error(
        "[calories-popup-update] Failed to parse AI response:",
        responseText,
      );
      return res
        .status(500)
        .json({ error: "Failed to parse AI response", message: responseText });
    }

    // Normalize and coerce to numbers
    const result = {
      blockId: blockId,
      calories: Number(parsed.calories ?? 0),
      protein: Number(parsed.protein ?? 0),
      fat: Number(parsed.fat ?? 0),
      carbs: Number(parsed.carbs ?? 0),
      fiber: Number(parsed.fiber ?? 0),
      sugar: Number(parsed.sugar ?? 0),
      sodium: Number(parsed.sodium ?? 0),
      confidence: Number(parsed.confidence ?? 0.5),
    };

    console.log(
      `[calories-popup-update] success calories=${result.calories} protein=${result.protein} fat=${result.fat} carbs=${result.carbs}`,
    );

    try {
      // Create a deep copy of blocks to avoid mutation
      const newBlocks = cloneBlocks(entry.blocks || []);
      const blockIndex = newBlocks.findIndex((b) => b.id === blockId);

      if (blockIndex === -1) {
        // This case should ideally not happen if blockId is validated
        console.error(
          `[calories-popup-update] Block with id ${blockId} not found in entry ${entryId}`,
        );
      } else {
        // Update the specific block with new nutritional data
        newBlocks[blockIndex] = {
          ...newBlocks[blockIndex],
          calories: result.calories,
          protein: result.protein,
          fat: result.fat,
          carbs: result.carbs,
          fiber: result.fiber,
          sugar: result.sugar,
          sodium: result.sodium,
          confidence: result.confidence,
        };

        // Recalculate totals for the entire entry
        const totals = AIService.calculateTotals(newBlocks);

        // Persist changes to the database
        await Database.query(
          `UPDATE diary_entries SET
             blocks = $1,
             total_calories = $2,
             total_protein = $3,
             total_fat = $4,
             total_carbs = $5,
             total_fiber = $6,
             total_sugar = $7,
             total_sodium = $8
           WHERE id = $9`,
          [
            JSON.stringify(newBlocks),
            totals.total_calories,
            totals.total_protein,
            totals.total_fat,
            totals.total_carbs,
            totals.total_fiber,
            totals.total_sugar,
            totals.total_sodium,
            entryId,
          ],
        );
        console.log(
          `[calories-popup-update] Persisted updated blocks and totals for entry ${entryId}`,
        );
      }
    } catch (dbError: any) {
      console.error(
        `[calories-popup-update] Failed to persist changes for entry ${entryId}`,
        {
          message: dbError?.message,
        },
      );
      // Decide if you want to bubble up the error to the client
      // For now, we log it and the client still gets the updated data for the session
    }

    res.json(result);
  } catch (error: any) {
    console.error(
      "/calories-popup-update error",
      error?.response?.data || error?.message || error,
    );
    res
      .status(500)
      .json({ error: "Internal server error", message: error?.message });
  }
});

export default router;
