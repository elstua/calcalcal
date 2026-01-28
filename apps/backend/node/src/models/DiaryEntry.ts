import Database from '../services/database';

export interface DiaryEntry {
  id: string;
  user_id: string;
  date: string;
  content: string;
  blocks: any[];
  total_calories: number;
  total_protein: number;
  total_fat: number;
  total_carbs: number;
  total_fiber: number;
  total_sugar: number;
  total_sodium: number;
  ai_analysis_status: string;
  ai_analysis_error: string | null;
  images: string[];
  created_at: string;
  updated_at: string;
}

export class DiaryEntryModel {
  static async listByDateRange(
    userId: string,
    dateFrom: string,
    dateTo: string
  ) {
    const result = await Database.query(
      `SELECT id, user_id, date, content, images, total_calories, updated_at, ai_analysis_status
       FROM diary_entries
       WHERE user_id = $1 AND date >= $2 AND date <= $3
       ORDER BY date DESC`,
      [userId, dateFrom, dateTo]
    );
    return result.rows;
  }

  static async listAnalyzedByDateRange(
    userId: string,
    dateFrom: string,
    dateTo: string
  ) {
    const result = await Database.query(
      `SELECT id, user_id, date, content, images, total_calories, updated_at
       FROM diary_entries
       WHERE user_id = $1 
         AND date >= $2 
         AND date <= $3 
         AND ai_analysis_status = 'completed'
       ORDER BY date ASC`,
      [userId, dateFrom, dateTo]
    );
    return result.rows;
  }

  static async getByDate(userId: string, date: string) {
    const result = await Database.query(
      `SELECT * FROM diary_entries
       WHERE user_id = $1 AND date = $2`,
      [userId, date]
    );
    return result.rows[0] || null;
  }

  static async getById(entryId: string) {
    const result = await Database.query(
      `SELECT * FROM diary_entries WHERE id = $1`,
      [entryId]
    );
    return result.rows[0] || null;
  }

  static async upsert(userId: string, date: string, content: string) {
    const result = await Database.query(
      `INSERT INTO diary_entries (user_id, date, content)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, date) 
       DO UPDATE SET content = $3, updated_at = NOW()
       RETURNING *`,
      [userId, date, content]
    );
    return result.rows[0];
  }

  static async updateContent(entryId: string, userId: string, content: string) {
    const result = await Database.query(
      `UPDATE diary_entries
       SET content = $1, updated_at = NOW()
       WHERE id = $2 AND user_id = $3
       RETURNING *`,
      [content, entryId, userId]
    );
    return result.rows[0] || null;
  }

  static async updateContentAndBlocks(entryId: string, userId: string, content: string, blocks: any[]) {
    const result = await Database.query(
      `UPDATE diary_entries
       SET content = $1, blocks = $2, updated_at = NOW()
       WHERE id = $3 AND user_id = $4
       RETURNING *`,
      [content, JSON.stringify(blocks), entryId, userId]
    );
    return result.rows[0] || null;
  }

  static async delete(entryId: string, userId: string) {
    const result = await Database.query(
      `DELETE FROM diary_entries
       WHERE id = $1 AND user_id = $2`,
      [entryId, userId]
    );
    return (result.rowCount ?? 0) > 0;
  }
}


