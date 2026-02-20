import { Router } from 'express';
import { AuthRequest, authenticateToken } from '../middleware/auth';
import { StreaksModel } from '../models/Streaks';
import { StreakCalculator } from '../services/streakCalculator';

const router = Router();

// Protect all streak routes
router.use(authenticateToken);

// GET /api/streaks - Get current streak information
router.get('/', async (req: AuthRequest, res) => {
  try {
    const userId = req.userId!;
    const recalculate = req.query.recalculate === 'true';
    console.log(`[GET /api/streaks] Request for user=${userId}, recalculate=${recalculate}`);

    // If recalculate flag is set, force recalculation from entries
    if (recalculate) {
      console.log(`[GET /api/streaks] Force recalculating streaks for user=${userId}`);
      await StreakCalculator.recalculateAllStreaks(userId);
    }

    // Get current streaks data
    let streaksData = await StreaksModel.getStreaksData(userId);
    console.log(`[GET /api/streaks] Found streaks: current=${streaksData?.currentStreak}, total=${streaksData?.totalDaysWithEntries}, lastEntry=${streaksData?.lastEntryDate}`);
    
    // Check if streak data needs recalculation
    const today = new Date().toISOString().split('T')[0];
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split('T')[0];

    const lastEntryIsRecent = streaksData?.lastEntryDate &&
      (streaksData.lastEntryDate === today || streaksData.lastEntryDate === yesterday);

    // Streak has expired: last entry is older than yesterday but currentStreak still > 0
    const streakExpired = streaksData && streaksData.currentStreak > 0 && !lastEntryIsRecent;

    // New entries the DB doesn't know about yet
    const { DiaryEntryModel } = await import('../models/DiaryEntry');
    const recentEntries = await DiaryEntryModel.listAnalyzedByDateRange(userId, yesterday, today);
    const hasRecentEntries = recentEntries.length > 0;
    const outOfSync = hasRecentEntries && !lastEntryIsRecent;

    const needsRecalc = streakExpired || outOfSync;
    console.log(`[GET /api/streaks] Staleness check: lastEntryIsRecent=${lastEntryIsRecent}, streakExpired=${streakExpired}, outOfSync=${outOfSync}`);

    // If no streaks data exists OR data needs recalculation, recalculate
    if (!streaksData || (streaksData.currentStreak === 0 && streaksData.totalDaysWithEntries === 0) || needsRecalc) {
      console.log(`[GET /api/streaks] Recalculating streaks for user=${userId} (expired=${streakExpired}, outOfSync=${outOfSync})`);
      await StreakCalculator.initializeUserStreaks(userId);
      await StreakCalculator.recalculateAllStreaks(userId);
      streaksData = await StreaksModel.getStreaksData(userId);
    }

    const response = {
      currentStreak: streaksData?.currentStreak || 0,
      longestStreak: streaksData?.longestStreak || 0,
      totalDaysWithEntries: streaksData?.totalDaysWithEntries || 0,
      lastEntryDate: streaksData?.lastEntryDate || null,
      streakStartDate: streaksData?.streakStartDate || null,
    };
    
    console.log(`[GET /api/streaks] Returning: current=${response.currentStreak}, longest=${response.longestStreak}, total=${response.totalDaysWithEntries}, lastEntry=${response.lastEntryDate}`);
    res.json(response);
  } catch (error) {
    console.error('[GET /api/streaks] Error:', error);
    res.status(500).json({ error: 'Failed to get streaks' });
  }
});

// GET /api/streaks/history - Get streak history
router.get('/history', async (req: AuthRequest, res) => {
  try {
    const userId = req.userId!;
    const limit = Math.min(parseInt(req.query.limit as string) || 10, 50);

    const streakHistory = await StreaksModel.getStreakHistory(userId, limit);

    res.json({
      streaks: streakHistory,
      total: streakHistory.length,
    });
  } catch (error) {
    console.error('Error getting streak history:', error);
    res.status(500).json({ error: 'Failed to get streak history' });
  }
});

// GET /api/streaks/statistics - Get detailed streak statistics
router.get('/statistics', async (req: AuthRequest, res) => {
  try {
    const userId = req.userId!;

    const statistics = await StreakCalculator.getStreakStatistics(userId);

    res.json(statistics);
  } catch (error) {
    console.error('Error getting streak statistics:', error);
    res.status(500).json({ error: 'Failed to get streak statistics' });
  }
});

// POST /api/streaks/recalculate - Recalculate streaks from scratch
router.post('/recalculate', async (req: AuthRequest, res) => {
  try {
    const userId = req.userId!;

    // Recalculate streaks from all diary entries
    const recalculatedStreaks = await StreakCalculator.recalculateAllStreaks(userId);

    res.json({
      message: 'Streaks recalculated successfully',
      streaks: recalculatedStreaks,
    });
  } catch (error) {
    console.error('Error recalculating streaks:', error);
    res.status(500).json({ error: 'Failed to recalculate streaks' });
  }
});

// GET /api/streaks/calendar - Get streak information for calendar view
router.get('/calendar', async (req: AuthRequest, res) => {
  try {
    const userId = req.userId!;
    const { startDate, endDate } = req.query;

    if (!startDate || !endDate) {
      return res.status(400).json({
        error: 'startDate and endDate query parameters are required',
      });
    }

    // Get diary entries for the date range
    const { DiaryEntryModel } = await import('../models/DiaryEntry');
    const entries = await DiaryEntryModel.listByDateRange(
      userId,
      String(startDate),
      String(endDate)
    );

    // Process entries to determine streak days
    const calendarData = entries.map(entry => ({
      date: entry.date,
      hasEntry: StreakCalculator.hasMeaningfulContent(
        entry.content || '',
        entry.blocks || []
      ),
      calories: entry.total_calories,
    }));

    // Get current streak info for context
    const streaksData = await StreaksModel.getStreaksData(userId);

    res.json({
      days: calendarData,
      currentStreak: streaksData?.currentStreak || 0,
      streakStartDate: streaksData?.streakStartDate || null,
    });
  } catch (error) {
    console.error('Error getting calendar streaks:', error);
    res.status(500).json({ error: 'Failed to get calendar streaks' });
  }
});

export default router;