import Database from '../services/database';

function normalizedBlockContent(block: any) {
  return String(block?.content || '').trim();
}

function hasMeaningfulNutrition(block: any) {
  return Boolean(
    Number(block?.calories) > 0 ||
      Number(block?.protein) > 0 ||
      Number(block?.fat) > 0 ||
      Number(block?.carbs) > 0
  );
}

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

  static async upsertContentAndBlocksByDate(userId: string, date: string, content: string, blocks: any[]) {
    const existing = await this.getByDate(userId, date);
    if (existing) {
      return this.updateContentAndBlocks(existing.id, userId, content, blocks);
    }

    const inserted = await Database.query(
      `INSERT INTO diary_entries (user_id, date, content, blocks)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (user_id, date) DO NOTHING
       RETURNING ${this.selectColumns}`,
      [userId, date, content, JSON.stringify(blocks)]
    );

    if (inserted.rows[0]) {
      return inserted.rows[0];
    }

    const conflicted = await this.getByDate(userId, date);
    if (!conflicted) {
      return null;
    }
    return this.updateContentAndBlocks(conflicted.id, userId, content, blocks);
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
    const existingBlocksByStableId = new Map();
    const existingBlocksByContent = new Map();
    for (const block of existingBlocks) {
      if (block.id) {
        existingBlocksMap.set(block.id, block);
      }
      if (block.stableId) {
        existingBlocksByStableId.set(block.stableId, block);
      }
      const normalizedContent = normalizedBlockContent(block);
      if (normalizedContent && hasMeaningfulNutrition(block) && !existingBlocksByContent.has(normalizedContent)) {
        existingBlocksByContent.set(normalizedContent, block);
      }
    }
    
    // Merge: keep nutrition data from existing blocks, update content/position from new blocks
    const mergedBlocks = blocks.map((newBlock: any) => {
      const normalizedNewContent = normalizedBlockContent(newBlock);
      const stableIdMatch = newBlock.stableId ? existingBlocksByStableId.get(newBlock.stableId) : null;
      const contentMatch = normalizedNewContent ? existingBlocksByContent.get(normalizedNewContent) : null;
      const existingBlock = existingBlocksMap.get(newBlock.id) ||
        (stableIdMatch && normalizedBlockContent(stableIdMatch) === normalizedNewContent ? stableIdMatch : null) ||
        contentMatch;
      if (existingBlock) {
        // Keep all nutrition data from existing block, but update content/position if changed
        const merged = {
          ...existingBlock,
          content: newBlock.content !== undefined ? newBlock.content : existingBlock.content,
          position: newBlock.position !== undefined ? newBlock.position : existingBlock.position,
          imageUrl: newBlock.imageUrl !== undefined ? newBlock.imageUrl : existingBlock.imageUrl,
          imageObjectKey: newBlock.imageObjectKey !== undefined ? newBlock.imageObjectKey : existingBlock.imageObjectKey,
          stableId: newBlock.stableId !== undefined ? newBlock.stableId : existingBlock.stableId,
          // Preserve these from existing:
          // calories, protein, fat, carbs, fiber, sugar, sodium, weight,
          // metric_description, confidence, ai_analysis, etc.
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

    // 🛡️ Defensive dedup: iOS-sync path can occasionally send two blocks with the
    // same stableId or the same normalized content under different ids (state-drift
    // bug, see references/diary-blocks-debugging.md). Collapse those here so we
    // never double-count calories. Preference order on collision:
    //   1. userModified: true wins
    //   2. block with meaningful nutrition data wins
    //   3. otherwise keep the earlier (lower-position) block
    // Skip position-1 placeholder ("write what you ate today") — it is always pos 1
    // and is intentionally allowed to repeat across entries.
    const PLACEHOLDER = 'write what you ate today';
    const blockScore = (b: any) => {
      const userMod = b?.userModified === true ? 2 : 0;
      const hasNut = hasMeaningfulNutrition(b) ? 1 : 0;
      return userMod + hasNut;
    };
    const seenStableId = new Map<string, number>(); // stableId -> index in dedupedBlocks
    const seenContent = new Map<string, number>(); // normalized content -> index in dedupedBlocks
    const dedupedBlocks: any[] = [];
    let droppedDuplicates = 0;
    for (const block of mergedBlocks) {
      const normalized = normalizedBlockContent(block).toLowerCase();
      const isPlaceholder = normalized === PLACEHOLDER || normalized === '';
      const stableId = block?.stableId;

      let collidedIdx = -1;
      if (stableId && seenStableId.has(stableId)) {
        collidedIdx = seenStableId.get(stableId)!;
      } else if (!isPlaceholder && normalized && seenContent.has(normalized)) {
        collidedIdx = seenContent.get(normalized)!;
      }

      if (collidedIdx >= 0) {
        const existing = dedupedBlocks[collidedIdx];
        const incomingScore = blockScore(block);
        const existingScore = blockScore(existing);
        droppedDuplicates += 1;
        console.warn(
          `[DiaryEntry] Dropping duplicate block in entry=${entryId} ` +
            `(content="${normalized.slice(0, 40)}", incomingScore=${incomingScore}, existingScore=${existingScore})`
        );
        if (incomingScore > existingScore) {
          // Replace existing with incoming, preserve position of the original
          dedupedBlocks[collidedIdx] = { ...block, position: existing.position };
          if (stableId) seenStableId.set(stableId, collidedIdx);
          if (!isPlaceholder && normalized) seenContent.set(normalized, collidedIdx);
        }
        // else: keep existing, drop incoming
        continue;
      }

      const idx = dedupedBlocks.length;
      dedupedBlocks.push(block);
      if (stableId) seenStableId.set(stableId, idx);
      if (!isPlaceholder && normalized) seenContent.set(normalized, idx);
    }

    if (droppedDuplicates > 0) {
      // Renumber positions to be contiguous starting at the first block's position.
      // Preserve the leading placeholder at position 1 if present.
      const basePos = dedupedBlocks.length > 0
        ? Number(dedupedBlocks[0]?.position ?? 1)
        : 1;
      dedupedBlocks.forEach((b, i) => {
        b.position = basePos + i;
      });
      console.warn(
        `[DiaryEntry] Defensive dedup removed ${droppedDuplicates} duplicate block(s) from entry=${entryId}, ` +
          `final count=${dedupedBlocks.length}`
      );
    }

    const result = await Database.query(
      `UPDATE diary_entries
       SET content = $1, blocks = $2, updated_at = NOW()
       WHERE id = $3 AND user_id = $4
       RETURNING ${this.selectColumns}`,
      [content, JSON.stringify(dedupedBlocks), entryId, userId]
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

  /**
   * Manually overwrite a single block's nutrition (calories, macros, items)
   * without running AI. Used by the editable nutrition sheet: the client sends
   * the recomputed per-item breakdown and totals, we persist it, mark the block
   * userModified, and recompute entry-level totals from all blocks.
   */
  static async updateBlockManualNutrition(
    entryId: string,
    userId: string,
    blockId: string,
    nutrition: {
      calories?: number;
      protein?: number;
      fat?: number;
      carbs?: number;
      fiber?: number;
      sugar?: number;
      sodium?: number;
      weight?: number;
      metric_description?: string;
      items?: any[];
    }
  ) {
    const entry = await this.getById(entryId);
    if (!entry || entry.user_id !== userId) {
      return null;
    }

    let matched = false;
    const updatedBlocks = (entry.blocks || []).map((block: any) => {
      if (block.id !== blockId) {
        return block;
      }
      matched = true;
      return {
        ...block,
        calories: Number(nutrition.calories) || 0,
        protein: Number(nutrition.protein) || 0,
        fat: Number(nutrition.fat) || 0,
        carbs: Number(nutrition.carbs) || 0,
        fiber: Number(nutrition.fiber) || 0,
        sugar: Number(nutrition.sugar) || 0,
        sodium: Number(nutrition.sodium) || 0,
        weight:
          nutrition.weight !== undefined && nutrition.weight !== null
            ? Number(nutrition.weight)
            : block.weight,
        metric_description:
          nutrition.metric_description ?? block.metric_description,
        items: Array.isArray(nutrition.items) ? nutrition.items : block.items,
        userModified: true,
        lastAnalyzedAt: new Date().toISOString(),
      };
    });

    if (!matched) {
      return null;
    }

    const totals = updatedBlocks.reduce(
      (acc: any, block: any) => ({
        total_calories: acc.total_calories + (Number(block.calories) || 0),
        total_protein: acc.total_protein + (Number(block.protein) || 0),
        total_fat: acc.total_fat + (Number(block.fat) || 0),
        total_carbs: acc.total_carbs + (Number(block.carbs) || 0),
        total_fiber: acc.total_fiber + (Number(block.fiber) || 0),
        total_sugar: acc.total_sugar + (Number(block.sugar) || 0),
        total_sodium: acc.total_sodium + (Number(block.sodium) || 0),
      }),
      {
        total_calories: 0,
        total_protein: 0,
        total_fat: 0,
        total_carbs: 0,
        total_fiber: 0,
        total_sugar: 0,
        total_sodium: 0,
      }
    );

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
         updated_at = NOW()
       WHERE id = $9 AND user_id = $10
       RETURNING ${this.selectColumns}`,
      [
        JSON.stringify(updatedBlocks),
        totals.total_calories,
        totals.total_protein,
        totals.total_fat,
        totals.total_carbs,
        totals.total_fiber,
        totals.total_sugar,
        totals.total_sodium,
        entryId,
        userId,
      ]
    );

    const updatedEntry = result.rows[0] || null;
    if (!updatedEntry) {
      return null;
    }

    const updatedBlock =
      (updatedEntry.blocks || []).find((b: any) => b.id === blockId) || null;
    return { entry: updatedEntry, block: updatedBlock, totals };
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
