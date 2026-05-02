import crypto from "crypto";
import { AIAnalysisJobModel } from "../../models/AIAnalysisJob";
import { AIAnalysisWorkflow } from "./analysisWorkflow";

export class AIAnalysisWorker {
  private static readonly workerId = `ai-worker-${crypto.randomUUID()}`;
  private static timer: NodeJS.Timeout | null = null;
  private static running = false;
  private static schemaWarningLogged = false;

  static start() {
    if (this.timer || process.env.AI_WORKER_ENABLED === "false") {
      return;
    }

    const intervalMs = this.getIntervalMs();
    this.timer = setInterval(() => {
      void this.drain();
    }, intervalMs);
    this.timer.unref?.();

    void this.drain();
    console.log(`[AIAnalysisWorker] started intervalMs=${intervalMs}`);
  }

  static stop() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
    this.running = false;
  }

  static kick() {
    if (process.env.AI_WORKER_ENABLED === "false") {
      return;
    }
    void this.drain();
  }

  private static async drain() {
    if (this.running) {
      return;
    }

    this.running = true;
    try {
      const batchSize = this.getBatchSize();
      for (let i = 0; i < batchSize; i += 1) {
        const job = await AIAnalysisJobModel.claimNext(
          this.workerId,
          this.getStaleAfterSeconds(),
        );
        if (!job) {
          break;
        }

        try {
          const result = await AIAnalysisWorkflow.executeFullEntryAnalysisJob({
            jobId: job.id,
            entryId: job.entry_id,
            userId: job.user_id,
            entryDate: job.entry_date,
            blocks: job.blocks || [],
          });

          if (result === "completed") {
            await AIAnalysisJobModel.complete(job.id);
          } else {
            await AIAnalysisJobModel.cancel(job.id, "Stale analysis job");
          }
        } catch (error: any) {
          await AIAnalysisJobModel.fail(
            job.id,
            error?.message || "Unknown error",
          );
        }
      }
    } catch (error) {
      if (AIAnalysisJobModel.isMissingJobsTableError(error)) {
        this.stop();
        if (!this.schemaWarningLogged) {
          this.schemaWarningLogged = true;
          console.warn(
            "[AIAnalysisWorker] ai_analysis_jobs table is missing. Run `npm run migrate:dev` from apps/backend/node, then restart the dev server.",
          );
        }
        return;
      }
      console.error("[AIAnalysisWorker] drain failed", error);
    } finally {
      this.running = false;
    }
  }

  private static getIntervalMs() {
    const value = Number(process.env.AI_WORKER_INTERVAL_MS ?? 2_000);
    return Number.isFinite(value) && value > 0 ? Math.floor(value) : 2_000;
  }

  private static getBatchSize() {
    const value = Number(process.env.AI_WORKER_BATCH_SIZE ?? 1);
    return Number.isFinite(value) && value > 0 ? Math.floor(value) : 1;
  }

  private static getStaleAfterSeconds() {
    const value = Number(process.env.AI_WORKER_STALE_AFTER_SECONDS ?? 300);
    return Number.isFinite(value) && value > 0 ? Math.floor(value) : 300;
  }
}
