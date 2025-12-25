import { StreaksModel, StreaksData } from '../models/Streaks';
import { DiaryEntryModel } from '../models/DiaryEntry';
import Database from './database';

export interface StreakCalculationOptions {
  timezoneOffset?: number; // User's timezone offset in minutes
  minimumContentLength?: number; // Minimum characters to count as meaningful
  ignorePlaceholderPrompts?: boolean;
}

export class StreakCalculator {
  private static readonly DEFAULT_OPTIONS: Required<StreakCalculationOptions> = {
    timezoneOffset: 0,
    minimumContentLength: 10,
    ignorePlaceholderPrompts: true,
  };

  private static readonly PLACEHOLDER_PATTERNS = [
    /what did you eat today/i,
    /describe your meals/i,
    /breakfast:\s*$/i,
    /lunch:\s*$/i,
    /dinner:\s*$/i,
    /snacks:\s*$/i,
  ];

  /**
   * Check if diary entry has meaningful content
   */
  static hasMeaningfulContent(
    content: string,
    blocks: any[],
    options: StreakCalculationOptions = {}
  ): boolean {
    const opts = { ...this.DEFAULT_OPTIONS, ...options };

    // Check content length
    const trimmedContent = content.trim();
    if (trimmedContent.length < opts.minimumContentLength) {
      return false;
    }

    // Check for placeholder prompts
    if (opts.ignorePlaceholderPrompts) {
      for (const pattern of this.PLACEHOLDER_PATTERNS) {
        if (pattern.test(trimmedContent)) {
          return false;
        }
      }
    }

    // Check if blocks have meaningful content
    if (blocks && blocks.length > 0) {
      const meaningfulBlocks = blocks.filter(
        (block: any) =>
          block.content &&
          typeof block.content === 'string' &&
          block.content.trim().length >= opts.minimumContentLength
      );
      return meaningfulBlocks.length > 0;
    }

    return true;
  }

  /**
   * Get user's timezone-aware date for a given timestamp
   */
  static getTimezoneAwareDate(
    timestamp: Date,
    timezoneOffset: number
  ): string {
    const adjustedDate = new Date(
      timestamp.getTime() + timezoneOffset * 60 * 1000
    );
    return adjustedDate.toISOString().split('T')[0];
  }

  /**
   * Calculate streaks for a user from their diary entries
   */
  static async calculateUserStreaks(
    userId: string,
    options: StreakCalculationOptions = {}
  ): Promise<StreaksData> {
    const opts = { ...this.DEFAULT_OPTIONS, ...options };

    // Get user's timezone offset
    const userTimezone = await this.getUserTimezoneOffset(userId);
    const timezoneOffset = opts.timezoneOffset || userTimezone;

    // Get all diary entries for the user
    const entries = await DiaryEntryModel.listByDateRange(
      userId,
      '2020-01-01', // Far enough in the past
      new Date().toISOString().split('T')[0]
    );

    // Process entries to calculate streaks
    return this.processEntriesForStreaks(entries, timezoneOffset);
  }

  /**
   * Process diary entries array to calculate streaks
   */
  private static async processEntriesForStreaks(
    entries: any[],
    timezoneOffset: number
  ): Promise<StreaksData> {
    let currentStreak = 0;
    let longestStreak = 0;
    let totalDaysWithEntries = 0;
    let lastEntryDate: string | null = null;
    let streakStartDate: string | null = null;
    let currentStreakStart: string | null = null;

    // Sort entries by date
    entries.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());

    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      const entryDate = entry.date;
      const hasContent = this.hasMeaningfulContent(
        entry.content || '',
        entry.blocks || []
      );

      if (hasContent) {
        totalDaysWithEntries++;
        lastEntryDate = entryDate;

        if (i === 0) {
          // First entry with content
          currentStreak = 1;
          currentStreakStart = entryDate;
          streakStartDate = entryDate;
        } else {
          // Check if this entry is consecutive to the previous one
          const prevEntry = entries[i - 1];
          const prevDate = new Date(prevEntry.date);
          const currDate = new Date(entryDate);
          const daysDiff = Math.floor(
            (currDate.getTime() - prevDate.getTime()) / (1000 * 60 * 60 * 24)
          );

          if (daysDiff === 1) {
            // Consecutive day - extend current streak
            currentStreak++;
          } else {
            // Gap in days - start new streak
            currentStreak = 1;
            currentStreakStart = entryDate;
          }
        }

        // Update longest streak if needed
        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
          streakStartDate = currentStreakStart;
        }
      } else {
        // Entry without content - reset current streak
        currentStreak = 0;
        currentStreakStart = null;
      }
    }

    return {
      currentStreak,
      longestStreak,
      totalDaysWithEntries,
      lastEntryDate,
      streakStartDate,
    };
  }

  /**
   * Update streaks when a diary entry is created or updated
   */
  static async updateStreaksOnEntryChange(
    userId: string,
    entryDate: string,
    content: string,
    blocks: any[]
  ): Promise<void> {
    // Get current streaks data
    const currentStreaks = await StreaksModel.getCurrentStreaks(userId);

    // Check if entry has meaningful content
    const hasContent = this.hasMeaningfulContent(content, blocks);

    // Get user's timezone
    const timezoneOffset = await this.getUserTimezoneOffset(userId);
    const today = this.getTimezoneAwareDate(new Date(), timezoneOffset);

    // Calculate yesterday relative to the entry date (not today)
    const entryDateObj = new Date(entryDate);
    const yesterdayOfEntry = new Date(entryDateObj);
    yesterdayOfEntry.setDate(yesterdayOfEntry.getDate() - 1);
    const yesterdayOfEntryStr = yesterdayOfEntry.toISOString().split('T')[0];

    if (hasContent) {
      // User has meaningful content - update streak
      let newCurrentStreak = 1;
      let newStreakStart = entryDate;

      // Check if this is a same-day update (don't increment total_days)
      const isSameDayUpdate = currentStreaks?.last_entry_date === entryDate;

      if (currentStreaks?.last_entry_date === yesterdayOfEntryStr) {
        // Continue existing streak (entry is day after last entry)
        newCurrentStreak = (currentStreaks.current_streak || 0) + 1;
        newStreakStart = currentStreaks.streak_start_date || entryDate;
      } else if (isSameDayUpdate) {
        // Same day update - keep current streak values
        newCurrentStreak = currentStreaks.current_streak || 1;
        newStreakStart = currentStreaks.streak_start_date || entryDate;
      }
      // else: gap in days - reset streak to 1 (default values)

      const newLongestStreak = Math.max(
        newCurrentStreak,
        currentStreaks?.longest_streak || 0
      );

      // Only increment total_days_with_entries for new unique dates
      const newTotalDays = isSameDayUpdate
        ? (currentStreaks?.total_days_with_entries || 0)
        : (currentStreaks?.total_days_with_entries || 0) + 1;

      await StreaksModel.updateStreak(
        userId,
        newCurrentStreak,
        newLongestStreak,
        entryDate,
        newStreakStart,
        newTotalDays
      );
    } else {
      // Entry has no meaningful content - check if this breaks the streak
      if (currentStreaks?.last_entry_date === yesterdayOfEntryStr) {
        // Move current streak to history
        if (currentStreaks.current_streak > 0) {
          await StreaksModel.addToHistory(
            userId,
            currentStreaks.current_streak,
            currentStreaks.streak_start_date || yesterdayOfEntryStr,
            yesterdayOfEntryStr
          );
        }

        // Reset current streak
        await StreaksModel.resetCurrentStreak(userId);
      }
    }
  }

  /**
   * Get user's timezone offset from database
   */
  private static async getUserTimezoneOffset(userId: string): Promise<number> {
    try {
      const result = await Database.query(
        'SELECT timezone_offset FROM user_profiles WHERE id = $1',
        [userId]
      );
      return result.rows[0]?.timezone_offset || 0;
    } catch (error) {
      console.error('Error getting user timezone:', error);
      return 0;
    }
  }

  /**
   * Recalculate all streaks for a user (for data repair)
   */
  static async recalculateAllStreaks(userId: string): Promise<StreaksData> {
    return await StreaksModel.recalculateStreaks(userId);
  }

  /**
   * Initialize streaks for a new user
   */
  static async initializeUserStreaks(userId: string): Promise<void> {
    await StreaksModel.initializeUserStreaks(userId);
  }

  /**
   * Get streak statistics for analytics
   */
  static async getStreakStatistics(userId: string): Promise<{
    currentStreak: number;
    longestStreak: number;
    totalDaysWithEntries: number;
    averageStreakLength: number;
    totalCompletedStreaks: number;
    recentStreaks: any[];
  }> {
    const streaksData = await StreaksModel.getStreaksData(userId);
    const streakHistory = await StreaksModel.getStreakHistory(userId, 50);

    // Calculate average streak length
    const totalCompletedStreaks = streakHistory.length;
    const averageStreakLength =
      totalCompletedStreaks > 0
        ? streakHistory.reduce((sum, streak) => sum + streak.streak_length, 0) /
        totalCompletedStreaks
        : 0;

    return {
      currentStreak: streaksData?.currentStreak || 0,
      longestStreak: streaksData?.longestStreak || 0,
      totalDaysWithEntries: streaksData?.totalDaysWithEntries || 0,
      averageStreakLength,
      totalCompletedStreaks,
      recentStreaks: streakHistory.slice(0, 5),
    };
  }
}