import { Router } from 'express';
import { AuthRequest, authenticateToken } from '../middleware/auth';
import { DiaryEntryModel } from '../models/DiaryEntry';
import { AIService } from '../services/ai/service';
import Database from '../services/database';

const router = Router();

router.use(authenticateToken);

// POST /api/ai/analyze
router.post('/analyze', async (req: AuthRequest, res) => {
  try {
    const { entryId, blocks } = req.body;
    const userId = req.userId!;

    if (!entryId || !Array.isArray(blocks)) {
      return res.status(400).json({
        error: 'entryId and blocks array are required',
      });
    }

    const entry = await DiaryEntryModel.getById(entryId);
    if (!entry || entry.user_id !== userId) {
      return res.status(404).json({ error: 'Entry not found' });
    }

    await Database.query(
      `UPDATE diary_entries SET ai_analysis_status = $1 WHERE id = $2`,
      ['processing', entryId]
    );

    try {
      const analyzedBlocks = await AIService.analyzeBlocks(blocks);
      const totals = AIService.calculateTotals(analyzedBlocks);

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
           ai_analysis_status = $9
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
          'completed',
          entryId,
        ]
      );

      res.json({ success: true, updatedBlocksCount: analyzedBlocks.length });
    } catch (error: any) {
      await Database.query(
        `UPDATE diary_entries SET ai_analysis_status = $1, ai_analysis_error = $2 WHERE id = $3`,
        ['failed', error?.message || 'Unknown error', entryId]
      );
      res.status(500).json({ error: 'Analysis failed', message: error?.message || 'Unknown error' });
    }
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;


