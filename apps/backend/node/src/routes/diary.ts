import { Router } from 'express';
import { AuthRequest, authenticateToken } from '../middleware/auth';
import { DiaryEntryModel } from '../models/DiaryEntry';

const router = Router();

// Protect all diary routes
router.use(authenticateToken);

// GET /api/diary/entries - List entries
router.get('/entries', async (req: AuthRequest, res) => {
  try {
    const { dateFrom, dateTo } = req.query;
    const userId = req.userId!;

    if (!dateFrom || !dateTo) {
      return res.status(400).json({
        error: 'dateFrom and dateTo query parameters are required',
      });
    }

    const entries = await DiaryEntryModel.listByDateRange(
      userId,
      String(dateFrom),
      String(dateTo)
    );

    res.json(entries);
  } catch (error) {
    console.error('Error listing entries:', error);
    res.status(500).json({ error: 'Failed to list entries' });
  }
});

// GET /api/diary/entries/:id - Get entry by ID
router.get('/entries/:id', async (req: AuthRequest, res) => {
  try {
    const { id } = req.params;
    const userId = req.userId!;

    const entry = await DiaryEntryModel.getById(id);
    if (!entry || entry.user_id !== userId) {
      return res.status(404).json({ error: 'Entry not found' });
    }

    res.json(entry);
  } catch (error) {
    console.error('Error getting entry:', error);
    res.status(500).json({ error: 'Failed to get entry' });
  }
});

// POST /api/diary/entries - Create entry
router.post('/entries', async (req: AuthRequest, res) => {
  try {
    const { date, content, blocks } = req.body;
    const userId = req.userId!;

    if (!date) {
      return res.status(400).json({ error: 'date is required' });
    }

    const entry = Array.isArray(blocks)
      ? await DiaryEntryModel.upsertContentAndBlocksByDate(userId, date, content || '', blocks)
      : await DiaryEntryModel.upsert(userId, date, content || '');
    // Note: Streaks update happens when AI analysis completes

    if (!entry) {
      return res.status(500).json({ error: 'Failed to create entry' });
    }

    res.status(201).json(entry);
  } catch (error) {
    console.error('Error creating entry:', error);
    res.status(500).json({ error: 'Failed to create entry' });
  }
});

// PATCH /api/diary/entries/:id - Update entry
router.patch('/entries/:id', async (req: AuthRequest, res) => {
  try {
    const { id } = req.params;
    const { content, blocks } = req.body;
    const userId = req.userId!;

    if (content === undefined && !blocks) {
      return res.status(400).json({ error: 'content or blocks is required' });
    }

    let entry;
    if (blocks && Array.isArray(blocks)) {
      // Update both content and blocks if blocks provided
      // Note: updateContentAndBlocks preserves nutrition data from AI analysis
      entry = await DiaryEntryModel.updateContentAndBlocks(id, userId, content || '', blocks);
    } else {
      // Fallback to content-only update
      entry = await DiaryEntryModel.updateContent(id, userId, content);
    }

    if (!entry) {
      return res.status(404).json({ error: 'Entry not found' });
    }
    // Note: Streaks update happens when AI analysis completes

    res.json(entry);
  } catch (error) {
    console.error('Error updating entry:', error);
    res.status(500).json({ error: 'Failed to update entry' });
  }
});

// PATCH /api/diary/entries/:entryId/blocks/:blockId/nutrition
// Manual nutrition override for a single block (editable nutrition sheet, no AI).
router.patch('/entries/:entryId/blocks/:blockId/nutrition', async (req: AuthRequest, res) => {
  try {
    const { entryId, blockId } = req.params;
    const { nutrition } = req.body;
    const userId = req.userId!;

    if (!nutrition || typeof nutrition !== 'object') {
      return res.status(400).json({ error: 'nutrition object is required' });
    }

    const result = await DiaryEntryModel.updateBlockManualNutrition(
      entryId,
      userId,
      blockId,
      nutrition
    );

    if (!result) {
      return res.status(404).json({ error: 'Entry or block not found' });
    }

    const { block, totals } = result;
    res.json({
      blockId,
      entryId,
      calories: Number(block?.calories) || 0,
      protein: Number(block?.protein) || 0,
      fat: Number(block?.fat) || 0,
      carbs: Number(block?.carbs) || 0,
      fiber: Number(block?.fiber) || 0,
      sugar: Number(block?.sugar) || 0,
      sodium: Number(block?.sodium) || 0,
      weight: block?.weight ?? null,
      metric_description: block?.metric_description ?? null,
      confidence: block?.confidence ?? null,
      items: block?.items ?? null,
      totals,
    });
  } catch (error) {
    console.error('Error updating block nutrition:', error);
    res.status(500).json({ error: 'Failed to update block nutrition' });
  }
});

// DELETE /api/diary/entries/:id - Delete entry
router.delete('/entries/:id', async (req: AuthRequest, res) => {
  try {
    const { id } = req.params;
    const userId = req.userId!;

    const entry = await DiaryEntryModel.getById(id);
    if (!entry || entry.user_id !== userId) {
      return res.status(404).json({ error: 'Entry not found' });
    }

    const success = await DiaryEntryModel.delete(id, userId);
    if (!success) {
      return res.status(404).json({ error: 'Entry not found' });
    }
    // Note: Deleting an entry doesn't affect streaks (already validated food stays counted)

    res.json({ success: true });
  } catch (error) {
    console.error('Error deleting entry:', error);
    res.status(500).json({ error: 'Failed to delete entry' });
  }
});

export default router;

