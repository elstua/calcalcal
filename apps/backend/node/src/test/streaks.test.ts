import { StreaksModel, StreaksData } from '../models/Streaks';
import { StreakCalculator } from '../services/streakCalculator';
import { DiaryEntryModel } from '../models/DiaryEntry';
import { UserModel } from '../models/User';
import Database from '../services/database';

describe('Streaks Functionality', () => {
  let testUserId: string;
  
  beforeAll(async () => {
    // Create a test user for streaks testing
    const testUser = await UserModel.createTemporaryUser('streaks-test-device-' + Date.now());
    testUserId = testUser.id;
    
    // Initialize streaks for the test user
    await StreakCalculator.initializeUserStreaks(testUserId);
  });
  
  afterAll(async () => {
    // Clean up test data
    await Database.query('DELETE FROM diary_entries WHERE user_id = $1', [testUserId]);
    await Database.query('DELETE FROM user_streaks WHERE user_id = $1', [testUserId]);
    await Database.query('DELETE FROM streak_history WHERE user_id = $1', [testUserId]);
    await Database.query('DELETE FROM user_profiles WHERE id = $1', [testUserId]);
  });
  
  beforeEach(async () => {
    // Clean up diary entries and streaks data before each test
    await Database.query('DELETE FROM diary_entries WHERE user_id = $1', [testUserId]);
    await Database.query('DELETE FROM user_streaks WHERE user_id = $1', [testUserId]);
    await Database.query('DELETE FROM streak_history WHERE user_id = $1', [testUserId]);
    await StreakCalculator.initializeUserStreaks(testUserId);
  });

  // Helper: mark entry as analyzed and set created_at to entry date (noon UTC).
  // This simulates "logged on that day" so streak retrospective filter includes them.
  async function markEntryAsAnalyzed(userId: string, date: string) {
    await Database.query(
      `UPDATE diary_entries 
       SET ai_analysis_status = 'completed', 
           total_calories = 100,
           created_at = ((date::text || ' 12:00:00')::timestamp AT TIME ZONE 'UTC')
       WHERE user_id = $1 AND date = $2::date`,
      [userId, date]
    );
  }

  // Like markEntryAsAnalyzed but does not change created_at (used for retrospective test).
  async function markEntryAsAnalyzedOnly(userId: string, date: string) {
    await Database.query(
      `UPDATE diary_entries 
       SET ai_analysis_status = 'completed', total_calories = 100 
       WHERE user_id = $1 AND date = $2::date`,
      [userId, date]
    );
  }

  describe('StreaksModel', () => {
    test('should initialize streaks for new user', async () => {
      const streaks = await StreaksModel.getStreaksData(testUserId);
      
      expect(streaks).toEqual({
        currentStreak: 0,
        longestStreak: 0,
        totalDaysWithEntries: 0,
        lastEntryDate: null,
        streakStartDate: null,
      });
    });

    test('should update streaks correctly', async () => {
      const result = await StreaksModel.updateStreak(
        testUserId,
        3,
        5,
        '2025-12-21',
        '2025-12-19',
        10
      );

      expect(result.current_streak).toBe(3);
      expect(result.longest_streak).toBe(5);
      expect(result.last_entry_date).toBeTruthy();
      expect(result.streak_start_date).toBeTruthy();
      expect(result.total_days_with_entries).toBe(10);
    });

    test('should add streak to history', async () => {
      const historyItem = await StreaksModel.addToHistory(
        testUserId,
        5,
        '2025-12-15',
        '2025-12-19'
      );

      expect(historyItem.user_id).toBe(testUserId);
      expect(historyItem.streak_length).toBe(5);
      expect(historyItem.start_date).toBeTruthy();
      expect(historyItem.end_date).toBeTruthy();
    });

    test('should get streak history', async () => {
      // Add some history items
      await StreaksModel.addToHistory(testUserId, 3, '2025-12-10', '2025-12-12');
      await StreaksModel.addToHistory(testUserId, 5, '2025-12-15', '2025-12-19');

      const history = await StreaksModel.getStreakHistory(testUserId);
      
      expect(history).toHaveLength(2);
      expect(history[0].streak_length).toBe(5); // Should be ordered by end_date DESC
      expect(history[1].streak_length).toBe(3);
    });
  });

  describe('StreakCalculator', () => {
    test('should identify meaningful content correctly', () => {
      const meaningfulContent = 'I had a healthy salad for lunch with grilled chicken and vegetables.';
      const placeholderContent = 'What did you eat today?';
      const emptyContent = '';
      
      expect(StreakCalculator.hasMeaningfulContent(meaningfulContent, [])).toBe(true);
      expect(StreakCalculator.hasMeaningfulContent(placeholderContent, [])).toBe(false);
      expect(StreakCalculator.hasMeaningfulContent(emptyContent, [])).toBe(false);
    });

    test('should calculate streaks from consecutive entries', async () => {
      // Create entries for 5 consecutive days ending today
      const today = new Date();
      for (let i = 4; i >= 0; i--) {
        const date = new Date(today);
        date.setDate(date.getDate() - i);
        const dateStr = date.toISOString().split('T')[0];

        await DiaryEntryModel.upsert(
          testUserId,
          dateStr,
          `Healthy eating day ${5-i}. Had salad and grilled chicken.`
        );
        await markEntryAsAnalyzed(testUserId, dateStr);
      }

      const streaks = await StreakCalculator.calculateUserStreaks(testUserId);

      expect(streaks.currentStreak).toBe(5);
      expect(streaks.longestStreak).toBe(5);
      expect(streaks.totalDaysWithEntries).toBe(5);
      expect(streaks.lastEntryDate).toBeTruthy();
      expect(streaks.streakStartDate).toBeTruthy();
    });

    test('should handle streak breaks correctly', async () => {
      // Create entries with a gap
      const today = new Date();
      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);
      const dayBeforeYesterday = new Date(today);
      dayBeforeYesterday.setDate(dayBeforeYesterday.getDate() - 2);
      const threeDaysAgo = new Date(today);
      threeDaysAgo.setDate(threeDaysAgo.getDate() - 3);
      const fourDaysAgo = new Date(today);
      fourDaysAgo.setDate(fourDaysAgo.getDate() - 4);

      await DiaryEntryModel.upsert(testUserId, fourDaysAgo.toISOString().split('T')[0], 'Healthy eating day 1');
      await markEntryAsAnalyzed(testUserId, fourDaysAgo.toISOString().split('T')[0]);
      await DiaryEntryModel.upsert(testUserId, threeDaysAgo.toISOString().split('T')[0], 'Healthy eating day 2');
      await markEntryAsAnalyzed(testUserId, threeDaysAgo.toISOString().split('T')[0]);
      // Skip dayBeforeYesterday (break)
      await DiaryEntryModel.upsert(testUserId, yesterday.toISOString().split('T')[0], 'Back on track day 1');
      await markEntryAsAnalyzed(testUserId, yesterday.toISOString().split('T')[0]);
      await DiaryEntryModel.upsert(testUserId, today.toISOString().split('T')[0], 'Back on track day 2');
      await markEntryAsAnalyzed(testUserId, today.toISOString().split('T')[0]);

      const streaks = await StreakCalculator.calculateUserStreaks(testUserId);

      expect(streaks.currentStreak).toBe(2); // Current streak should be 2 (yesterday-today)
      expect(streaks.longestStreak).toBe(2); // Longest should be 2
      expect(streaks.totalDaysWithEntries).toBe(4);
    });

    test('should only count analyzed entries in streak calculation', async () => {
      // Create entries - some analyzed, some not
      const today = new Date();
      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);
      const twoDaysAgo = new Date(today);
      twoDaysAgo.setDate(twoDaysAgo.getDate() - 2);
      const threeDaysAgo = new Date(today);
      threeDaysAgo.setDate(threeDaysAgo.getDate() - 3);

      await DiaryEntryModel.upsert(testUserId, threeDaysAgo.toISOString().split('T')[0], 'Entry 1');
      await markEntryAsAnalyzed(testUserId, threeDaysAgo.toISOString().split('T')[0]);
      await DiaryEntryModel.upsert(testUserId, twoDaysAgo.toISOString().split('T')[0], 'Entry 2');
      await markEntryAsAnalyzed(testUserId, twoDaysAgo.toISOString().split('T')[0]);
      await DiaryEntryModel.upsert(testUserId, yesterday.toISOString().split('T')[0], 'Entry 3 - not analyzed');
      // Skip marking as analyzed
      await DiaryEntryModel.upsert(testUserId, today.toISOString().split('T')[0], 'Entry 4');
      await markEntryAsAnalyzed(testUserId, today.toISOString().split('T')[0]);

      const streaks = await StreakCalculator.calculateUserStreaks(testUserId);

      // Should only count analyzed entries
      expect(streaks.currentStreak).toBe(1); // Only today is consecutive analyzed
      expect(streaks.totalDaysWithEntries).toBe(3); // 3 days ago, 2 days ago, and today
    });

    test('should recalculate streaks correctly', async () => {
      // Create some initial data - 3 consecutive days ending today
      const today = new Date();
      for (let i = 2; i >= 0; i--) {
        const date = new Date(today);
        date.setDate(date.getDate() - i);
        const dateStr = date.toISOString().split('T')[0];

        await DiaryEntryModel.upsert(testUserId, dateStr, `Day ${3-i}`);
        await markEntryAsAnalyzed(testUserId, dateStr);
      }

      // Manually set incorrect streaks data
      await StreaksModel.updateStreak(testUserId, 1, 1, today.toISOString().split('T')[0], today.toISOString().split('T')[0], 3);

      // Recalculate should fix it
      const recalculated = await StreakCalculator.recalculateAllStreaks(testUserId);

      expect(recalculated.currentStreak).toBe(3);
      expect(recalculated.longestStreak).toBe(3);
      expect(recalculated.totalDaysWithEntries).toBe(3);
    });

    test('should get streak statistics', async () => {
      // Create some streak history
      await StreaksModel.addToHistory(testUserId, 3, '2025-12-10', '2025-12-12');
      await StreaksModel.addToHistory(testUserId, 5, '2025-12-15', '2025-12-19');
      
      // Set current streaks
      await StreaksModel.updateStreak(testUserId, 2, 5, '2025-12-21', '2025-12-20', 7);
      
      const stats = await StreakCalculator.getStreakStatistics(testUserId);
      
      expect(stats.currentStreak).toBe(2);
      expect(stats.longestStreak).toBe(5);
      expect(stats.totalDaysWithEntries).toBe(7);
      expect(stats.totalCompletedStreaks).toBe(2);
      expect(stats.averageStreakLength).toBe(4); // (3 + 5) / 2
      expect(stats.recentStreaks).toHaveLength(2);
    });

    test('should not count retrospectively added days', async () => {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      const dateStr = yesterday.toISOString().split('T')[0];

      await DiaryEntryModel.upsert(testUserId, dateStr, 'Backfilled: had salad.');
      await markEntryAsAnalyzedOnly(testUserId, dateStr);

      const streaks = await StreakCalculator.calculateUserStreaks(testUserId);

      expect(streaks.currentStreak).toBe(0);
      expect(streaks.totalDaysWithEntries).toBe(0);
      expect(streaks.lastEntryDate).toBeNull();
    });
  });

  describe('Streak Update Triggers', () => {
    test('should update streaks when meaningful entry is analyzed', async () => {
      // Create a meaningful entry and mark it as analyzed
      const today = new Date().toISOString().split('T')[0];
      await DiaryEntryModel.upsert(
        testUserId,
        today,
        'Had a great healthy salad for lunch.'
      );
      await markEntryAsAnalyzed(testUserId, today);

      // Manually trigger streak update (no database trigger anymore)
      await StreakCalculator.updateStreaksOnAnalysisComplete(testUserId, today);

      const streaks = await StreaksModel.getStreaksData(testUserId);

      expect(streaks?.currentStreak).toBe(1);
      expect(streaks?.totalDaysWithEntries).toBe(1);
      expect(streaks?.lastEntryDate).toBeTruthy();
    });

    test('should not update streaks for placeholder content', async () => {
      // Create a placeholder entry
      await DiaryEntryModel.upsert(
        testUserId,
        '2025-12-21',
        'What did you eat today?'
      );

      // Wait a moment for trigger to process
      await new Promise(resolve => setTimeout(resolve, 100));

      const streaks = await StreaksModel.getStreaksData(testUserId);
      
      expect(streaks?.currentStreak).toBe(0);
      expect(streaks?.totalDaysWithEntries).toBe(0);
    });
  });
});