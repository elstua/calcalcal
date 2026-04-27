import { Router } from "express";
import { AuthRequest, authenticateToken } from "../middleware/auth";
import { DiaryEntryModel } from "../models/DiaryEntry";
import {
  AIAnalysisWorkflow,
  AIAnalysisWorkflowError,
} from "../services/ai/analysisWorkflow";

const router = Router();

router.use(authenticateToken);

function sendWorkflowError(res: any, error: AIAnalysisWorkflowError) {
  if (error.code === "request_timeout") {
    return res.status(error.statusCode).json({
      error: "Request timeout",
      message: error.message,
    });
  }

  if (error.code === "ai_analysis_failed") {
    return res.status(error.statusCode).json({
      error: "AI analysis failed",
      message: error.message,
    });
  }

  if (error.code === "entry_not_found") {
    return res.status(error.statusCode).json({ error: "Entry not found" });
  }

  if (error.code === "missing_analysis_content") {
    return res.status(error.statusCode).json({ error: error.message });
  }

  return res.status(error.statusCode).json({
    error: error.code,
    message: error.message,
  });
}

// POST /api/ai/analyze-block
router.post("/analyze-block", unifiedAnalyzeBlockHandler);

// Unified analyze-block handler
async function unifiedAnalyzeBlockHandler(req: AuthRequest, res: any) {
  try {
    const { blockId, entryId, content, userModified = false } = req.body;
    const userId = req.userId!;

    if (!blockId || !entryId || !content) {
      return res.status(400).json({
        error: "blockId, entryId, and content are required",
      });
    }

    const result = await AIAnalysisWorkflow.analyzeBlock({
      userId,
      blockId,
      entryId,
      content,
      userModified,
    });

    res.json(result);
  } catch (error: any) {
    console.error(
      "/analyze-block error",
      error?.response?.data || error?.message || error,
    );
    if (error instanceof AIAnalysisWorkflowError) {
      return sendWorkflowError(res, error);
    }

    res.status(500).json({
      error: "Internal server error",
      message: error?.message,
    });
  }
}

// Legacy endpoint - redirects to new unified endpoint
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

    await AIAnalysisWorkflow.startFullEntryAnalysis({
      entryId,
      userId,
      entryDate: entry.date,
      blocks,
    });

    return res
      .status(202)
      .json({ success: true, status: "processing", updatedBlocksCount: null });
  } catch (error) {
    res.status(500).json({ error: "Internal server error" });
  }
});

// Legacy endpoint - redirects to new unified endpoint
// POST /api/ai/analyze-image
router.post("/analyze-image", async (req: AuthRequest, res) => {
  try {
    const { imageUrl, entryId, blockId } = req.body || {};
    const userId = req.userId!;

    if (!imageUrl || !entryId || !blockId) {
      return res.status(400).json({
        error: "imageUrl, entryId, and blockId are required",
      });
    }

    const result = await AIAnalysisWorkflow.analyzeBlock({
      userId,
      entryId,
      blockId,
      content: {
        text: "",
        imageUrl,
      },
      userModified: false,
    });

    return res.json(result);
  } catch (error: any) {
    console.error(
      "/analyze-image error",
      error?.response?.data || error?.message || error,
    );
    if (error instanceof AIAnalysisWorkflowError) {
      return sendWorkflowError(res, error);
    }

    res.status(500).json({
      error: "Internal server error",
      message: error?.message,
    });
  }
});

// POST /api/ai/calories-popup-update - now integrates with unified analysis
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

    console.log(
      `[calories-popup-update] user=${userId} entry=${entryId} block=${blockId} calories=${calories} weight=${weight}`,
    );

    // Create block content structure for unified endpoint
    const userProvidedData: any = {};
    if (calories !== undefined) userProvidedData.calories = calories;
    if (weight !== undefined) userProvidedData.weight = weight;

    const result = await AIAnalysisWorkflow.analyzeBlock({
      userId,
      entryId,
      blockId,
      content: {
        text,
        imageUrl: undefined,
        userProvidedData,
      },
      userModified: true,
    });

    return res.json(result);
  } catch (error: any) {
    console.error(
      "/calories-popup-update error",
      error?.response?.data || error?.message || error,
    );
    if (error instanceof AIAnalysisWorkflowError) {
      return sendWorkflowError(res, error);
    }

    res.status(500).json({
      error: "Internal server error",
      message: error?.message,
    });
  }
});

export default router;
