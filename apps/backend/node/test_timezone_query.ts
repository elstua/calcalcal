
import { DiaryEntryModel } from './src/models/DiaryEntry';
import Database from './src/services/database';
import { v4 as uuidv4 } from 'uuid';

async function testListByDateRange() {
    try {
        const userId = uuidv4();
        const futureDate = new Date();
        futureDate.setDate(futureDate.getDate() + 1); // Tomorrow
        const futureDateStr = futureDate.toISOString().split('T')[0];

        // Insert entry for tomorrow
        await Database.query(`INSERT INTO user_profiles (id, created_at, updated_at) VALUES ($1, NOW(), NOW())`, [userId]);
        await DiaryEntryModel.upsert(userId, futureDateStr, 'Future entry');

        // Query with today's date as end date (simulate streakCalculator behavior)
        const todayStr = new Date().toISOString().split('T')[0];
        const results = await DiaryEntryModel.listByDateRange(userId, '2020-01-01', todayStr);

        console.log('Future Date:', futureDateStr);
        console.log('Query End Date:', todayStr);
        console.log('Results Found:', results.length);

        if (results.length === 0) {
            console.log('CONFIRMED: listByDateRange excludes future dates when range is capped at today.');
        } else {
            console.log('DEBUNKED: listByDateRange includes future dates?');
        }

        // Cleanup
        await Database.query('DELETE FROM diary_entries WHERE user_id = $1', [userId]);
        await Database.query('DELETE FROM user_profiles WHERE id = $1', [userId]);

    } catch (e) {
        console.error(e);
    } finally {
        process.exit(0);
    }
}

testListByDateRange();
