import Database from '../services/database';

export interface AIAnalysisCacheRow {
  analysis_result: any;
  confidence: number;
}

export class AIAnalysisCacheModel {
  static async getByContentHash(hash: string): Promise<AIAnalysisCacheRow | null> {
    const result = await Database.query<AIAnalysisCacheRow>(
      `SELECT analysis_result, confidence FROM ai_analysis_cache WHERE content_hash = $1`,
      [hash]
    );
    return result.rows[0] || null;
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
            usage_total_tokens
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
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
        ]
      );
    } catch (error) {
      // Caching failures are non-blocking
      // Intentionally swallow errors to not disrupt analysis flow
    }
  }
}


