
import { StreakCalculator } from '../services/streakCalculator';
import { DiaryEntryModel } from '../models/DiaryEntry';
import { StreaksModel } from '../models/Streaks';
import Database from '../services/database';
import { v4 as uuidv4 } from 'uuid';

async function testStreakRewrite() {
    const userId = uuidv4();
    console.log('Running Streak Rewrite Test with User ID:', userId);

    try {
        // 1. Create User
        await Database.query(`INSERT INTO user_profiles (id, created_at, updated_at) VALUES ($1, NOW(), NOW())`, [userId]);

        // 2. Insert Entries
        // helper to insert completed entry
        const insertCompleted = async (date: string, content: string) => {
            const id = uuidv4();
            await Database.query(`INSERT INTO diary_entries (id, user_id, date, content, ai_analysis_status) VALUES ($1, $2, $3, $4, 'pending')`,
                [id, userId, date, content]);
            await Database.query(`UPDATE diary_entries SET ai_analysis_status = 'completed' WHERE id = $1`, [id]);
        };

        // Day 1: Completed analysis (Valid) -> 2024-01-01
        await insertCompleted('2024-01-01', 'Entry 1');

        // Day 2: Pending analysis (Invalid for streak) -> 2024-01-02
        await Database.query(`INSERT INTO diary_entries (id, user_id, date, content, ai_analysis_status) VALUES ($1, $2, $3, $4, 'pending')`,
            [uuidv4(), userId, '2024-01-02', 'Entry 2']);

        // Day 3: Completed analysis (Valid, but gap due to day 2) -> 2024-01-03
        await insertCompleted('2024-01-03', 'Entry 3');

        // Day 4: Future date, Completed (Valid) -> Tomorrow
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        const tomorrowStr = tomorrow.toISOString().split('T')[0];
        await insertCompleted(tomorrowStr, 'Future Entry');

        // Day 3 and Tomorrow are separate streaks if today is treated strictly?
        // Let's see how it behaves.

        // 3. Run Calculation
        console.log('Calculating streaks...');
        const result = await StreakCalculator.calculateUserStreaks(userId);
        console.log('Result:', result);

        const analyzedEntries = await DiaryEntryModel.listAnalyzedByDateRange(userId, '2020-01-01', '2100-01-01');
        console.log('Analyzed Entries found:', analyzedEntries.length);
        analyzedEntries.forEach(e => console.log(` - ${e.date} (${e.ai_analysis_status})`));

        // Assertions
        // Expected:
        // 2024-01-01: Valid
        // 2024-01-02: Invalid (Pending) -> Break
        // 2024-01-03: Valid -> Start new streak
        // Tomorrow: Valid -> ... gap depends on "today"

        // Actually, "Tomorrow" and "2024-01-03" are far apart (unless today is 2024-01-04).
        // Assuming "today" is the real today (2025+).
        // The test creates '2024' entries which are in the past.
        // So 2024-01-03 is last entry before "tomorrow". Huge gap.
        // So streak should be just 1 (for tomorrow) if that is the last entry.

        // Let's adjust dates to be relative to today to check connectivity.

        await Database.query('DELETE FROM diary_entries WHERE user_id = $1', [userId]);

        const today = new Date();
        const todayStr = today.toISOString().split('T')[0];

        const yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);
        const yesterdayStr = yesterday.toISOString().split('T')[0];

        const twoDaysAgo = new Date(today);
        twoDaysAgo.setDate(twoDaysAgo.getDate() - 2);
        const twoDaysAgoStr = twoDaysAgo.toISOString().split('T')[0];

        // Case 1: 3 days consecutive, all completed
        await insertCompleted(twoDaysAgoStr, 'C');
        await insertCompleted(yesterdayStr, 'C');
        await insertCompleted(todayStr, 'C');

        const resultConsecutive = await StreakCalculator.calculateUserStreaks(userId);
        console.log('Consecutive (3 days):', resultConsecutive.currentStreak);
        if (resultConsecutive.currentStreak !== 3) throw new Error(`Expected 3, got ${resultConsecutive.currentStreak}`);

        // Case 2: Break in middle (yesterday pending)
        await Database.query(`UPDATE diary_entries SET ai_analysis_status = 'pending' WHERE user_id = $1 AND date = $2`, [userId, yesterdayStr]);

        const resultBroken = await StreakCalculator.calculateUserStreaks(userId);
        console.log('Broken (Yesterday pending):', resultBroken.currentStreak);
        if (resultBroken.currentStreak !== 1) throw new Error(`Expected 1 (just today), got ${resultBroken.currentStreak}`);

        console.log('✅ ALL TESTS PASSED');

    } catch (e) {
        console.error('❌ TEST FAILED:', e);
    } finally {
        // Cleanup
        await Database.query('DELETE FROM user_streaks WHERE user_id = $1', [userId]);
        await Database.query('DELETE FROM diary_entries WHERE user_id = $1', [userId]);
        await Database.query('DELETE FROM user_profiles WHERE id = $1', [userId]);
        process.exit(0);
    }
}

testStreakRewrite();
