
import Database from '../services/database';
import { v4 as uuidv4 } from 'uuid';

async function debugTest() {
    const userId = uuidv4();
    console.log('Debug Test User:', userId);

    try {
        await Database.query(`INSERT INTO user_profiles (id, created_at, updated_at) VALUES ($1, NOW(), NOW())`, [userId]);

        const entryId = uuidv4();
        await Database.query(
            `INSERT INTO diary_entries (id, user_id, date, content, ai_analysis_status) VALUES ($1, $2, $3, $4, $5)`,
            [entryId, userId, '2025-01-01', 'Debug Content', 'pending']
        );
        await Database.query(
            `UPDATE diary_entries SET ai_analysis_status = 'completed' WHERE id = $1`,
            [entryId]
        );
        console.log('Inserted entry');

        const result = await Database.query(`SELECT * FROM diary_entries WHERE user_id = $1`, [userId]);
        console.log('Query Result Count:', result.rows.length);
        if (result.rows.length > 0) {
            console.log('Row:', result.rows[0]);
        }

        const filtered = await Database.query(
            `SELECT * FROM diary_entries WHERE user_id = $1 AND ai_analysis_status = 'completed'`,
            [userId]
        );
        console.log(`Filtered 'completed' Result Count:`, filtered.rows.length);

    } catch (e) {
        console.error(e);
    } finally {
        process.exit(0);
    }
}

debugTest();
