import Database from "../services/database";

export interface AIAnalysisJob {
  id: string;
  entry_id: string;
  user_id: string;
  entry_date: string;
  job_type: "full_entry";
  status: "queued" | "processing" | "completed" | "failed" | "cancelled";
  blocks: any[];
  error: string | null;
  attempts: number;
  locked_at: string | null;
  locked_by: string | null;
  created_at: string;
  updated_at: string;
}

export class AIAnalysisJobModel {
  private static readonly selectColumns = `
    id, entry_id, user_id, to_char(entry_date, 'YYYY-MM-DD') AS entry_date,
    job_type, status, blocks, error, attempts, locked_at, locked_by, created_at, updated_at
  `;
  private static readonly jobsSelectColumns = `
    jobs.id, jobs.entry_id, jobs.user_id, to_char(jobs.entry_date, 'YYYY-MM-DD') AS entry_date,
    jobs.job_type, jobs.status, jobs.blocks, jobs.error, jobs.attempts, jobs.locked_at, jobs.locked_by,
    jobs.created_at, jobs.updated_at
  `;

  static async enqueueFullEntry(params: {
    jobId: string;
    entryId: string;
    userId: string;
    entryDate: string | Date;
    blocks: any[];
  }) {
    const result = await Database.query<AIAnalysisJob>(
      `INSERT INTO ai_analysis_jobs (id, entry_id, user_id, entry_date, blocks)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (id) DO UPDATE
       SET status = 'queued',
           blocks = EXCLUDED.blocks,
           error = NULL,
           locked_at = NULL,
           locked_by = NULL,
           updated_at = NOW()
       RETURNING ${this.selectColumns}`,
      [
        params.jobId,
        params.entryId,
        params.userId,
        params.entryDate,
        JSON.stringify(params.blocks),
      ],
    );
    return result.rows[0] || null;
  }

  static async claimNext(workerId: string, staleAfterSeconds: number) {
    const result = await Database.query<AIAnalysisJob>(
      `WITH next_job AS (
         SELECT id
         FROM ai_analysis_jobs
         WHERE status = 'queued'
            OR (
              status = 'processing'
              AND locked_at < NOW() - ($1::int * INTERVAL '1 second')
            )
         ORDER BY created_at ASC
         LIMIT 1
         FOR UPDATE SKIP LOCKED
       )
       UPDATE ai_analysis_jobs jobs
       SET status = 'processing',
           attempts = attempts + 1,
           locked_at = NOW(),
           locked_by = $2,
           updated_at = NOW()
       FROM next_job
       WHERE jobs.id = next_job.id
       RETURNING ${this.jobsSelectColumns}`,
      [staleAfterSeconds, workerId],
    );
    return result.rows[0] || null;
  }

  static async complete(jobId: string) {
    const result = await Database.query<AIAnalysisJob>(
      `UPDATE ai_analysis_jobs
       SET status = 'completed',
           error = NULL,
           locked_at = NULL,
           locked_by = NULL,
           updated_at = NOW()
       WHERE id = $1
       RETURNING ${this.selectColumns}`,
      [jobId],
    );
    return result.rows[0] || null;
  }

  static async fail(jobId: string, error: string) {
    const result = await Database.query<AIAnalysisJob>(
      `UPDATE ai_analysis_jobs
       SET status = 'failed',
           error = $2,
           locked_at = NULL,
           locked_by = NULL,
           updated_at = NOW()
       WHERE id = $1
       RETURNING ${this.selectColumns}`,
      [jobId, error],
    );
    return result.rows[0] || null;
  }

  static async cancel(jobId: string, reason: string) {
    const result = await Database.query<AIAnalysisJob>(
      `UPDATE ai_analysis_jobs
       SET status = 'cancelled',
           error = $2,
           locked_at = NULL,
           locked_by = NULL,
           updated_at = NOW()
       WHERE id = $1
       RETURNING ${this.selectColumns}`,
      [jobId, reason],
    );
    return result.rows[0] || null;
  }

  static isMissingJobsTableError(error: unknown) {
    return (
      typeof error === "object" &&
      error !== null &&
      "code" in error &&
      (error as { code?: string }).code === "42P01"
    );
  }
}
