import { StreaksModel, StreaksData } from '../models/Streaks';
import { DiaryEntryModel } from '../models/DiaryEntry';
import Database from './database';

export interface StreakCalculationOptions {
  timezoneOffset?: number; // User's timezone offset in minutes
}

export class StreakCalculator {
  private static readonly DEFAULT_OPTIONS: Required<StreakCalculationOptions> = {
    timezoneOffset: 0,
  };
  
  // Debouncing map to prevent race conditions from multiple simultaneous analysis jobs
  private static pendingUpdates = new Map<string, NodeJS.Timeout>();
  private static readonly DEBOUNCE_MS = 1000;

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
   * Calculate streaks for a user based on completed AI analysis
   * This replaces the old SQL-based logic
   */
  static async calculateUserStreaks(
    userId: string,
    options: StreakCalculationOptions = {}
  ): Promise<StreaksData> {
    console.log(`[StreakCalculator] Starting calculation for user=${userId}`);
    const opts = { ...this.DEFAULT_OPTIONS, ...options };

    // Get user's timezone offset
    const userTimezone = await this.getUserTimezoneOffset(userId);
    const timezoneOffset = opts.timezoneOffset || userTimezone;
    console.log(`[StreakCalculator] Using timezone offset=${timezoneOffset} minutes`);

    // Get today's local date
    const todayLocal = this.getTimezoneAwareDate(new Date(), timezoneOffset);
    console.log(`[StreakCalculator] Today (local)=${todayLocal}`);

    // Fetch all analyzed entries (we filter retrospectively-added ones below)
    const entries = await DiaryEntryModel.listAnalyzedByDateRange(
      userId,
      '2020-01-01',
      '2100-01-01'
    );
    console.log(`[StreakCalculator] Found ${entries.length} analyzed entries`);

    // Process entries to calculate streaks (excludes retrospective backfills)
    const result = await this.processEntriesForStreaks(
      userId,
      entries,
      todayLocal,
      timezoneOffset
    );
    console.log(`[StreakCalculator] Result: current=${result.currentStreak}, longest=${result.longestStreak}, total=${result.totalDaysWithEntries}, lastEntry=${result.lastEntryDate}`);
    
    return result;
  }

  /**
   * Process diary entries array to calculate streaks.
   * Excludes "retrospective" entries: we only count a day if the user logged it on or
   * before that calendar day (created_at local date <= entry date). Editing a past day
   * later does not add to streak.
   */
  private static async processEntriesForStreaks(
    userId: string,
    entries: any[],
    todayLocal: string,
    timezoneOffset: number
  ): Promise<StreaksData> {
    let currentStreak = 0;
    let longestStreak = 0;
    let totalDaysWithEntries = 0;
    let lastEntryDate: string | null = null;
    let streakStartDate: string | null = null;
    let currentStreakStart: string | null = null;

    // Filter out retrospective backfills: only count entries logged on or before their date
    const createdAt = (e: any): Date => (e.created_at ? new Date(e.created_at) : new Date(0));
    const entryDateStr = (e: any): string => {
      const d = new Date(e.date);
      return d.toISOString().split('T')[0];
    };
    const loggedDateStr = (e: any): string =>
      this.getTimezoneAwareDate(createdAt(e), timezoneOffset);

    const nonRetrospective = entries.filter((e) => {
      const logged = loggedDateStr(e);
      const entryDate = entryDateStr(e);
      const ok = logged <= entryDate;
      if (!ok) {
        console.log(`[StreakCalculator] Excluding retrospective: date=${entryDate} logged=${logged}`);
      }
      return ok;
    });
    console.log(`[StreakCalculator] After retrospective filter: ${nonRetrospective.length} entries`);

    // Filter out entries without meaningful content (empty, placeholder, too short)
    const meaningful = nonRetrospective.filter((e) => {
      const ok = StreakCalculator.hasMeaningfulContent(e.content || '', e.blocks || []);
      if (!ok) {
        console.log(`[StreakCalculator] Excluding non-meaningful: date=${entryDateStr(e)} content="${(e.content || '').substring(0, 30)}"`);
      }
      return ok;
    });
    console.log(`[StreakCalculator] After meaningful content filter: ${meaningful.length} entries`);

    // Unique dates from filtered list, deduplicated and sorted
    const uniqueDateStrings = Array.from(
      new Set(meaningful.map(entryDateStr))
    ).sort();

    for (let i = 0; i < uniqueDateStrings.length; i++) {
      const entryDate = uniqueDateStrings[i];
      totalDaysWithEntries++;
      lastEntryDate = entryDate;

      if (i === 0) {
        currentStreak = 1;
        currentStreakStart = entryDate;
        streakStartDate = entryDate;
      } else {
        const prevDate = new Date(uniqueDateStrings[i - 1]);
        const currDate = new Date(entryDate);
        const daysDiff = Math.floor(
          (currDate.getTime() - prevDate.getTime()) / (1000 * 60 * 60 * 24)
        );

        if (daysDiff === 1) {
          // Consecutive
          currentStreak++;
        } else {
          // Gap
          // Save previous streak to history if > 0? 
          // The old logic did this. For now we just reset.
          currentStreak = 1;
          currentStreakStart = entryDate;
        }
      }

      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }
    }

    // streakStartDate should always reflect the current streak's start, not the longest
    streakStartDate = currentStreakStart;

    // logic to reset current streak if the gap is too large relative to TODAY
    // If the last entry was yesterday or today, the streak is alive.
    // If the last entry was before yesterday, the current streak is effectively broken/zero,
    // BUT we might interpret it as "0" or just "frozen".
    // Standard logic: if lastEntry < yesterday, currentStreak = 0.

    if (lastEntryDate) {
      const lastDateObj = new Date(lastEntryDate);
      const todayObj = new Date(todayLocal);
      const yesterdayObj = new Date(todayObj);
      yesterdayObj.setDate(yesterdayObj.getDate() - 1);

      // precise diff
      const daysSinceLastEntry = Math.floor(
        (todayObj.getTime() - lastDateObj.getTime()) / (1000 * 60 * 60 * 24)
      );

      if (daysSinceLastEntry > 1) {
        currentStreak = 0;
        // streakStartDate usually stays as the start of the *last valid streak* or null?
        // Usually UI shows "0 days", streak start is irrelevant or null.
        streakStartDate = null;
      }
    }

    // Persist to DB
    await StreaksModel.updateStreak(
      userId,
      currentStreak,
      longestStreak,
      lastEntryDate,
      streakStartDate, // This might need to be carefully handled if currentStreak is 0
      totalDaysWithEntries
    );

    return {
      currentStreak,
      longestStreak,
      totalDaysWithEntries,
      lastEntryDate,
      streakStartDate,
    };
  }

  /**
   * Update streaks when AI analysis completes successfully
   * Debounced to prevent race conditions from multiple simultaneous analysis jobs
   */
  static async updateStreaksOnAnalysisComplete(
    userId: string,
    entryDate: string | Date
  ): Promise<void> {
    // Clear existing pending update for this user
    if (this.pendingUpdates.has(userId)) {
      clearTimeout(this.pendingUpdates.get(userId)!);
      console.log(`[StreakCalculator] Debouncing - clearing previous update for user=${userId}`);
    }
    
    // Schedule new update after debounce period
    return new Promise((resolve) => {
      const timeoutId = setTimeout(async () => {
        this.pendingUpdates.delete(userId);
        console.log(`[StreakCalculator] Debounced update executing for user=${userId}`);
        await this.calculateUserStreaks(userId);
        console.log(`[StreakCalculator] Debounced update completed for user=${userId}`);
        resolve();
      }, this.DEBOUNCE_MS);
      
      this.pendingUpdates.set(userId, timeoutId);
      console.log(`[StreakCalculator] Streak update scheduled for user=${userId} (${this.DEBOUNCE_MS}ms debounce)`);
    });
  }

  /**
   * Get user's timezone offset from database
   */
  static async getUserTimezoneOffset(userId: string): Promise<number> {
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
    return this.calculateUserStreaks(userId);
  }

  /**
   * Initialize streaks for a new user
   */
  static async initializeUserStreaks(userId: string): Promise<void> {
    await StreaksModel.initializeUserStreaks(userId);
  }

  /**
   * Get detailed streak statistics
   */
  static async getStreakStatistics(userId: string): Promise<any> {
    const streaksData = await StreaksModel.getStreaksData(userId);
    const history = await StreaksModel.getStreakHistory(userId, 50);

    const totalCompletedStreaks = history.length;
    const averageStreakLength = totalCompletedStreaks > 0
      ? Math.round(history.reduce((sum, h) => sum + h.streak_length, 0) / totalCompletedStreaks)
      : 0;

    return {
      currentStreak: streaksData?.currentStreak || 0,
      longestStreak: streaksData?.longestStreak || 0,
      totalDaysWithEntries: streaksData?.totalDaysWithEntries || 0,
      lastEntryDate: streaksData?.lastEntryDate || null,
      streakStartDate: streaksData?.streakStartDate || null,
      totalCompletedStreaks,
      averageStreakLength,
      recentStreaks: history.map(h => ({
        length: h.streak_length,
        startDate: h.start_date,
        endDate: h.end_date,
      })),
    };
  }

  /**
   * Check if content has meaningful information (not placeholder)
   */
  static hasMeaningfulContent(content: string, blocks: any[] = []): boolean {
    const placeholders = [
      'what did you eat today?',
      'describe your meals',
      'log your food',
      'track your calories',
      'add your meals',
      '',
    ];

    const normalizedContent = content?.trim().toLowerCase() || '';

    if (placeholders.includes(normalizedContent)) {
      return false;
    }

    if (normalizedContent.length < 10) {
      return false;
    }

    if (blocks && blocks.length > 0) {
      return true;
    }

    return true;
  }
}
