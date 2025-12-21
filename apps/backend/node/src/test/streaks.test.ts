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
      // Create entries for 5 consecutive days
      const today = new Date('2025-12-21');
      for (let i = 4; i >= 0; i--) {
        const date = new Date(today);
        date.setDate(date.getDate() - i);
        const dateStr = date.toISOString().split('T')[0];
        
        await DiaryEntryModel.upsert(
          testUserId,
          dateStr,
          `Healthy eating day ${5-i}. Had salad and grilled chicken.`
        );
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
      await DiaryEntryModel.upsert(testUserId, '2025-12-17', 'Healthy eating day 1');
      await DiaryEntryModel.upsert(testUserId, '2025-12-18', 'Healthy eating day 2');
      // Skip 2025-12-19 (break)
      await DiaryEntryModel.upsert(testUserId, '2025-12-20', 'Back on track day 1');
      await DiaryEntryModel.upsert(testUserId, '2025-12-21', 'Back on track day 2');

      const streaks = await StreakCalculator.calculateUserStreaks(testUserId);
      
      expect(streaks.currentStreak).toBe(2); // Current streak should be 2 (20-21)
      expect(streaks.longestStreak).toBe(2); // Longest should be 2
      expect(streaks.totalDaysWithEntries).toBe(4);
    });

    test('should ignore placeholder content in streak calculation', async () => {
      // Create entries with placeholder content
      await DiaryEntryModel.upsert(testUserId, '2025-12-17', 'What did you eat today?');
      await DiaryEntryModel.upsert(testUserId, '2025-12-18', 'Healthy eating with salad');
      await DiaryEntryModel.upsert(testUserId, '2025-12-19', 'Describe your meals');
      await DiaryEntryModel.upsert(testUserId, '2025-12-20', 'Grilled chicken and vegetables');

      const streaks = await StreakCalculator.calculateUserStreaks(testUserId);
      
      // Should only count meaningful content days
      expect(streaks.currentStreak).toBe(1); // Only 2025-12-20 is meaningful
      expect(streaks.totalDaysWithEntries).toBe(2); // 2025-12-18 and 2025-12-20
    });

    test('should recalculate streaks correctly', async () => {
      // Create some initial data
      await DiaryEntryModel.upsert(testUserId, '2025-12-17', 'Day 1');
      await DiaryEntryModel.upsert(testUserId, '2025-12-18', 'Day 2');
      await DiaryEntryModel.upsert(testUserId, '2025-12-19', 'Day 3');
      
      // Manually set incorrect streaks data
      await StreaksModel.updateStreak(testUserId, 1, 1, '2025-12-17', '2025-12-17', 3);
      
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
  });

  describe('Streak Update Triggers', () => {
    test('should update streaks when meaningful entry is created', async () => {
      // Create a meaningful entry
      await DiaryEntryModel.upsert(
        testUserId,
        '2025-12-21',
        'Had a great healthy salad for lunch.'
      );

      // Wait a moment for trigger to process
      await new Promise(resolve => setTimeout(resolve, 100));

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