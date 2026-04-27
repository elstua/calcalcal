ALTER TABLE "public"."diary_entries"
  ADD COLUMN IF NOT EXISTS "ai_analysis_job_id" "uuid",
  ADD COLUMN IF NOT EXISTS "ai_analysis_requested_at" timestamp with time zone;

CREATE INDEX IF NOT EXISTS "idx_diary_entries_ai_analysis_job_id"
  ON "public"."diary_entries" ("ai_analysis_job_id");
