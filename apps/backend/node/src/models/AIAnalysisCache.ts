import Database from '../services/database';

export interface AIAnalysisCacheRow {
  analysis_result: any;
  confidence: number;
  normalized_content?: string;
  original_variants?: string[];
  hit_count?: number;
  source?: string;
  unit_description?: string;
  unit_calories?: number;
  normalized_hash?: string;
  content?: string;
}

export class AIAnalysisCacheModel {
  static async getByContentHash(hash: string, promptVersion: string = 'v1'): Promise<AIAnalysisCacheRow | null> {
    const result = await Database.query<AIAnalysisCacheRow>(
      `SELECT analysis_result, confidence
       FROM ai_analysis_cache
       WHERE content_hash = $1
         AND COALESCE(prompt_version, 'v1') = $2`,
      [hash, promptVersion]
    );
    return result.rows[0] || null;
  }

  /**
   * Look up a cache entry by its normalized_hash (SHA256 of normalized+canonical item name).
   * Returns the full row including smart cache columns.
   */
  static async getByNormalizedHash(hash: string, promptVersion: string = 'v1'): Promise<AIAnalysisCacheRow | null> {
    const result = await Database.query<AIAnalysisCacheRow>(
      `SELECT analysis_result, confidence, normalized_content, original_variants,
              hit_count, source, unit_description, unit_calories, normalized_hash, content
       FROM ai_analysis_cache
       WHERE normalized_hash = $1
         AND COALESCE(prompt_version, 'v1') = $2`,
      [hash, promptVersion]
    );
    return result.rows[0] || null;
  }

  /**
   * Fuzzy match using pg_trgm similarity(). Returns the best match above threshold.
   * Threshold defaults to 0.3 (pg_trgm default). Values closer to 1.0 are more similar.
   */
  static async getByFuzzyMatch(
    content: string,
    threshold: number = 0.3,
    promptVersion: string = 'v1'
  ): Promise<AIAnalysisCacheRow | null> {
    const result = await Database.query<AIAnalysisCacheRow>(
      `SELECT analysis_result, confidence, normalized_content, original_variants,
              hit_count, source, unit_description, unit_calories, normalized_hash, content,
              similarity(normalized_content, $1) AS sim
       FROM ai_analysis_cache
       WHERE normalized_content IS NOT NULL
         AND similarity(normalized_content, $1) > $2
         AND COALESCE(prompt_version, 'v1') = $3
       ORDER BY sim DESC
       LIMIT 1`,
      [content, threshold, promptVersion]
    );
    return result.rows[0] || null;
  }

  /**
   * Increment the hit_count for a cache entry identified by normalized_hash.
   */
  static async incrementHitCount(hash: string): Promise<void> {
    try {
      await Database.query(
        `UPDATE ai_analysis_cache SET hit_count = hit_count + 1 WHERE normalized_hash = $1`,
        [hash]
      );
    } catch {
      // Non-blocking
    }
  }

  /**
   * Append a new variant string to the original_variants array for a cache entry.
   */
  static async updateVariants(hash: string, newVariant: string): Promise<void> {
    try {
      await Database.query(
        `UPDATE ai_analysis_cache
         SET original_variants = array_append(original_variants, $2)
         WHERE normalized_hash = $1
           AND NOT ($2 = ANY(original_variants))`,
        [hash, newVariant]
      );
    } catch {
      // Non-blocking
    }
  }

  static async insert(args: {
    contentHash: string;
    content: string;
    analysisResult: any;
    confidence: number;
    rawResponseText?: string;
    providerModel?: string;
    temperature?: number;
    promptVersion?: string;
    parseOk?: boolean;
    parseErrorText?: string | null;
    attempt?: 'primary' | 'retry';
    usagePromptTokens?: number;
    usageCompletionTokens?: number;
    usageTotalTokens?: number;
    // New smart cache fields
    normalizedContent?: string;
    originalVariants?: string[];
    hitCount?: number;
    source?: string;
    unitDescription?: string;
    unitCalories?: number;
    normalizedHash?: string;
  }): Promise<void> {
    const {
      contentHash,
      content,
      analysisResult,
      confidence,
      rawResponseText,
      providerModel,
      temperature,
      promptVersion,
      parseOk,
      parseErrorText,
      attempt,
      usagePromptTokens,
      usageCompletionTokens,
      usageTotalTokens,
      normalizedContent,
      originalVariants,
      hitCount,
      source,
      unitDescription,
      unitCalories,
      normalizedHash,
    } = args;

    try {
      await Database.query(
        `INSERT INTO ai_analysis_cache (
            content_hash,
            content,
            analysis_result,
            confidence,
            raw_response_text,
            provider_model,
            temperature,
            prompt_version,
            parse_ok,
            parse_error_text,
            attempt,
            usage_prompt_tokens,
            usage_completion_tokens,
            usage_total_tokens,
            normalized_content,
            original_variants,
            hit_count,
            source,
            unit_description,
            unit_calories,
            normalized_hash
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21)
        ON CONFLICT (content_hash) DO NOTHING`,
        [
          contentHash,
          content,
          JSON.stringify(analysisResult),
          confidence,
          rawResponseText || null,
          providerModel || null,
          temperature ?? null,
          promptVersion || null,
          parseOk ?? null,
          parseErrorText || null,
          attempt || null,
          usagePromptTokens ?? null,
          usageCompletionTokens ?? null,
          usageTotalTokens ?? null,
          normalizedContent || null,
          originalVariants || null,
          hitCount ?? 0,
          source || 'llm',
          unitDescription || null,
          unitCalories ?? null,
          normalizedHash || null,
        ]
      );
    } catch (error) {
      // Caching failures are non-blocking
      // Intentionally swallow errors to not disrupt analysis flow
    }
  }
}
