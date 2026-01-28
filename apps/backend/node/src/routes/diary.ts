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
    const { date, content } = req.body;
    const userId = req.userId!;

    if (!date) {
      return res.status(400).json({ error: 'date is required' });
    }

    const entry = await DiaryEntryModel.upsert(userId, date, content || '');
    // Note: Streaks update happens when AI analysis completes

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

    if (!content) {
      return res.status(400).json({ error: 'content is required' });
    }

    let entry;
    if (blocks && Array.isArray(blocks)) {
      // Update both content and blocks if blocks provided
      entry = await DiaryEntryModel.updateContentAndBlocks(id, userId, content, blocks);
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


