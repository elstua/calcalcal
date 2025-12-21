import Database from '../services/database';

export interface UserStreaks {
  user_id: string;
  current_streak: number;
  longest_streak: number;
  last_entry_date: string | null;
  streak_start_date: string | null;
  total_days_with_entries: number;
  updated_at: string;
}

export interface StreakHistoryItem {
  id: string;
  user_id: string;
  streak_length: number;
  start_date: string;
  end_date: string;
  created_at: string;
}

export interface StreaksData {
  currentStreak: number;
  longestStreak: number;
  totalDaysWithEntries: number;
  lastEntryDate: string | null;
  streakStartDate: string | null;
}

export class StreaksModel {
  static async getCurrentStreaks(userId: string): Promise<UserStreaks | null> {
    const result = await Database.query(
      `SELECT user_id, current_streak, longest_streak, 
              last_entry_date, streak_start_date, 
              total_days_with_entries, updated_at
       FROM user_streaks
       WHERE user_id = $1`,
      [userId]
    );
    return result.rows[0] as UserStreaks | null;
  }

  static async getStreaksData(userId: string): Promise<StreaksData | null> {
    const result = await Database.query(
      `SELECT current_streak, longest_streak, 
              last_entry_date, streak_start_date,
              total_days_with_entries
       FROM user_streaks
       WHERE user_id = $1`,
      [userId]
    );

    if (result.rows.length === 0) {
      return {
        currentStreak: 0,
        longestStreak: 0,
        totalDaysWithEntries: 0,
        lastEntryDate: null,
        streakStartDate: null,
      };
    }

    const row = result.rows[0];
    return {
      currentStreak: row.current_streak,
      longestStreak: row.longest_streak,
      totalDaysWithEntries: row.total_days_with_entries,
      lastEntryDate: row.last_entry_date,
      streakStartDate: row.streak_start_date,
    };
  }

  static async getStreakHistory(
    userId: string,
    limit: number = 10
  ): Promise<StreakHistoryItem[]> {
    const result = await Database.query(
      `SELECT id, user_id, streak_length, start_date, end_date, created_at
       FROM streak_history
       WHERE user_id = $1
       ORDER BY end_date DESC, streak_length DESC
       LIMIT $2`,
      [userId, limit]
    );
    return result.rows as StreakHistoryItem[];
  }

  static async updateStreak(
    userId: string,
    currentStreak: number,
    longestStreak: number,
    lastEntryDate: string | null,
    streakStartDate: string | null,
    totalDaysWithEntries: number
  ): Promise<UserStreaks> {
    const result = await Database.query(
      `INSERT INTO user_streaks (
        user_id, current_streak, longest_streak, 
        last_entry_date, streak_start_date,
        total_days_with_entries, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, NOW())
      ON CONFLICT (user_id) DO UPDATE SET
        current_streak = EXCLUDED.current_streak,
        longest_streak = EXCLUDED.longest_streak,
        last_entry_date = EXCLUDED.last_entry_date,
        streak_start_date = EXCLUDED.streak_start_date,
        total_days_with_entries = EXCLUDED.total_days_with_entries,
        updated_at = NOW()
      RETURNING *`,
      [
        userId,
        currentStreak,
        longestStreak,
        lastEntryDate,
        streakStartDate,
        totalDaysWithEntries,
      ]
    );
    return result.rows[0] as UserStreaks;
  }

  static async resetCurrentStreak(userId: string): Promise<void> {
    await Database.query(
      `UPDATE user_streaks
       SET current_streak = 0, 
           last_entry_date = NULL, 
           streak_start_date = NULL,
           updated_at = NOW()
       WHERE user_id = $1`,
      [userId]
    );
  }

  static async addToHistory(
    userId: string,
    streakLength: number,
    startDate: string,
    endDate: string
  ): Promise<StreakHistoryItem> {
    const result = await Database.query(
      `INSERT INTO streak_history (user_id, streak_length, start_date, end_date)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [userId, streakLength, startDate, endDate]
    );
    return result.rows[0] as StreakHistoryItem;
  }

  static async recalculateStreaks(userId: string): Promise<StreaksData> {
    // Get all diary entries for the user, ordered by date
    const entriesResult = await Database.query(
      `SELECT date, content, blocks, 
              public.has_meaningful_content(content, blocks) as has_content
       FROM diary_entries
       WHERE user_id = $1
       ORDER BY date ASC`,
      [userId]
    );

    const entries = entriesResult.rows;
    let currentStreak = 0;
    let longestStreak = 0;
    let totalDaysWithEntries = 0;
    let streakStart: string | null = null;
    let lastEntryDate: string | null = null;
    let currentStreakStart: string | null = null;

    // Process entries to calculate streaks
    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      const entryDate = new Date(entry.date);
      const hasContent = entry.has_content;

      if (hasContent) {
        totalDaysWithEntries++;
        lastEntryDate = entry.date;

        if (i === 0) {
          // First entry with content
          currentStreak = 1;
          currentStreakStart = entry.date;
          streakStart = entry.date;
        } else {
          // Check if this entry is consecutive to the previous one
          const prevEntry = entries[i - 1];
          const prevDate = new Date(prevEntry.date);
          const daysDiff = Math.floor(
            (entryDate.getTime() - prevDate.getTime()) / (1000 * 60 * 60 * 24)
          );

          if (daysDiff === 1 && prevEntry.has_content) {
            // Consecutive day - extend current streak
            currentStreak++;
          } else {
            // Gap in days - start new streak
            if (currentStreak > 0) {
              // Save previous streak to history if it's meaningful
              await this.addToHistory(
                userId,
                currentStreak,
                currentStreakStart!,
                prevEntry.date
              );
            }
            currentStreak = 1;
            currentStreakStart = entry.date;
          }
        }

        // Update longest streak if needed
        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
          streakStart = currentStreakStart;
        }
      } else {
        // Entry without content - reset current streak
        if (currentStreak > 0) {
          // Save current streak to history
          await this.addToHistory(
            userId,
            currentStreak,
            currentStreakStart!,
            lastEntryDate!
          );
        }
        currentStreak = 0;
        currentStreakStart = null;
      }
    }

    // Update user_streaks table with calculated values
    await this.updateStreak(
      userId,
      currentStreak,
      longestStreak,
      lastEntryDate,
      currentStreakStart,
      totalDaysWithEntries
    );

    return {
      currentStreak,
      longestStreak,
      totalDaysWithEntries,
      lastEntryDate,
      streakStartDate: currentStreakStart,
    };
  }

  static async initializeUserStreaks(userId: string): Promise<void> {
    // Check if user already has streaks data
    const existing = await this.getCurrentStreaks(userId);
    if (existing) {
      return;
    }

    // Initialize with zeros
    await Database.query(
      `INSERT INTO user_streaks (
        user_id, current_streak, longest_streak, 
        last_entry_date, streak_start_date,
        total_days_with_entries, updated_at
      ) VALUES ($1, 0, 0, NULL, NULL, 0, NOW())
      ON CONFLICT (user_id) DO NOTHING`,
      [userId]
    );
  }
}