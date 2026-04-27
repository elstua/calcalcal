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
  ai_analysis_job_id: string | null;
  ai_analysis_requested_at: string | null;
  images: string[];
  created_at: string;
  updated_at: string;
}

export class DiaryEntryModel {
  private static readonly selectColumns = `
    id, user_id, to_char(date, 'YYYY-MM-DD') AS date, content, blocks, images,
    total_calories, total_protein, total_fat, total_carbs, total_fiber, total_sugar, total_sodium,
    ai_analysis_status, ai_analysis_error, ai_analysis_job_id, ai_analysis_requested_at, created_at, updated_at
  `;

  static async listByDateRange(
    userId: string,
    dateFrom: string,
    dateTo: string
  ) {
    const result = await Database.query(
      `SELECT ${this.selectColumns}
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
      `SELECT ${this.selectColumns}
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
      `SELECT ${this.selectColumns}
       FROM diary_entries
       WHERE user_id = $1 AND date = $2`,
      [userId, date]
    );
    return result.rows[0] || null;
  }

  static async getById(entryId: string) {
    const result = await Database.query(
      `SELECT ${this.selectColumns}
       FROM diary_entries WHERE id = $1`,
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
       RETURNING ${this.selectColumns}`,
      [userId, date, content]
    );
    return result.rows[0];
  }

  static async updateContent(entryId: string, userId: string, content: string) {
    const result = await Database.query(
      `UPDATE diary_entries
       SET content = $1, updated_at = NOW()
       WHERE id = $2 AND user_id = $3
       RETURNING ${this.selectColumns}`,
      [content, entryId, userId]
    );
    return result.rows[0] || null;
  }

  static async updateContentAndBlocks(entryId: string, userId: string, content: string, blocks: any[]) {
    // ⚠️ CRITICAL: When updating blocks from iOS, we must preserve nutrition data from AI analysis
    // iOS sends blocks without nutrition data (just id, content, position)
    // We need to merge with existing blocks to keep calories, protein, etc.
    
    console.log(`[DiaryEntry] updateContentAndBlocks entry=${entryId}, incoming blocks=${blocks.length}`);
    
    // First, get existing blocks to preserve nutrition data
    const existing = await this.getById(entryId);
    const existingBlocks = existing?.blocks || [];
    const existingStatus = existing?.ai_analysis_status;
    
    console.log(`[DiaryEntry] Existing: status=${existingStatus}, blocks=${existingBlocks.length}`);
    
    // Check if content actually changed (to avoid unnecessary re-analysis)
    const contentChanged = existing?.content !== content;
    console.log(`[DiaryEntry] Content changed: ${contentChanged}`);
    
    // Create a map of existing blocks by ID for fast lookup
    const existingBlocksMap = new Map();
    for (const block of existingBlocks) {
      if (block.id) {
        existingBlocksMap.set(block.id, block);
      }
    }
    
    // Merge: keep nutrition data from existing blocks, update content/position from new blocks
    const mergedBlocks = blocks.map((newBlock: any) => {
      const existingBlock = existingBlocksMap.get(newBlock.id);
      if (existingBlock) {
        // Keep all nutrition data from existing block, but update content/position if changed
        const merged = {
          ...existingBlock,
          content: newBlock.content !== undefined ? newBlock.content : existingBlock.content,
          position: newBlock.position !== undefined ? newBlock.position : existingBlock.position,
          // Preserve these from existing:
          // calories, protein, fat, carbs, fiber, sugar, sodium, weight,
          // metric_description, confidence, ai_analysis, imageUrl, imageObjectKey, etc.
        };
        
        // Check if this specific block's content changed
        const blockContentChanged = newBlock.content !== existingBlock.content;
        if (blockContentChanged) {
          console.log(`[DiaryEntry] Block ${newBlock.id} content changed, preserving nutrition data`);
        }
        
        return merged;
      }
      // New block (not in existing) - use as-is
      console.log(`[DiaryEntry] New block ${newBlock.id} added`);
      return newBlock;
    });
    
    console.log(`[DiaryEntry] Merged blocks=${mergedBlocks.length}, preserving nutrition data`);
    
    const result = await Database.query(
      `UPDATE diary_entries
       SET content = $1, blocks = $2, updated_at = NOW()
       WHERE id = $3 AND user_id = $4
       RETURNING ${this.selectColumns}`,
      [content, JSON.stringify(mergedBlocks), entryId, userId]
    );
    
    const updated = result.rows[0] || null;
    console.log(`[DiaryEntry] Update complete: status=${updated?.ai_analysis_status}`);
    
    return updated;
  }

  static async startAnalysisJob(entryId: string, userId: string, jobId: string) {
    const result = await Database.query(
      `UPDATE diary_entries
       SET ai_analysis_status = $1,
           ai_analysis_error = NULL,
           ai_analysis_job_id = $2,
           ai_analysis_requested_at = NOW(),
           updated_at = NOW()
       WHERE id = $3 AND user_id = $4
       RETURNING ${this.selectColumns}`,
      ["processing", jobId, entryId, userId]
    );
    return result.rows[0] || null;
  }

  static async completeAnalysisJob(
    entryId: string,
    jobId: string,
    blocks: any[],
    totals: {
      total_calories: number;
      total_protein: number;
      total_fat: number;
      total_carbs: number;
      total_fiber: number;
      total_sugar: number;
      total_sodium: number;
    }
  ) {
    const result = await Database.query(
      `UPDATE diary_entries SET
         blocks = $1,
         total_calories = $2,
         total_protein = $3,
         total_fat = $4,
         total_carbs = $5,
         total_fiber = $6,
         total_sugar = $7,
         total_sodium = $8,
         ai_analysis_status = $9,
         ai_analysis_error = NULL,
         updated_at = NOW()
       WHERE id = $10 AND ai_analysis_job_id = $11
       RETURNING ${this.selectColumns}`,
      [
        JSON.stringify(blocks),
        totals.total_calories,
        totals.total_protein,
        totals.total_fat,
        totals.total_carbs,
        totals.total_fiber,
        totals.total_sugar,
        totals.total_sodium,
        "completed",
        entryId,
        jobId,
      ]
    );
    return result.rows[0] || null;
  }

  static async failAnalysisJob(entryId: string, jobId: string, message: string) {
    const result = await Database.query(
      `UPDATE diary_entries
       SET ai_analysis_status = $1,
           ai_analysis_error = $2,
           updated_at = NOW()
       WHERE id = $3 AND ai_analysis_job_id = $4
       RETURNING ${this.selectColumns}`,
      ["failed", message, entryId, jobId]
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
