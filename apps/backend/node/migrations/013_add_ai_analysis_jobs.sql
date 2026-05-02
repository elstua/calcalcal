CREATE TABLE IF NOT EXISTS "public"."ai_analysis_jobs" (
    "id" "uuid" PRIMARY KEY,
    "entry_id" "uuid" NOT NULL REFERENCES "public"."diary_entries"("id") ON DELETE CASCADE,
    "user_id" "uuid" NOT NULL REFERENCES "public"."user_profiles"("id") ON DELETE CASCADE,
    "entry_date" "date" NOT NULL,
    "job_type" "text" NOT NULL DEFAULT 'full_entry',
    "status" "text" NOT NULL DEFAULT 'queued',
    "blocks" "jsonb" NOT NULL DEFAULT '[]'::"jsonb",
    "error" "text",
    "attempts" integer NOT NULL DEFAULT 0,
    "locked_at" timestamp with time zone,
    "locked_by" "text",
    "created_at" timestamp with time zone NOT NULL DEFAULT "now"(),
    "updated_at" timestamp with time zone NOT NULL DEFAULT "now"(),
    CONSTRAINT "ai_analysis_jobs_job_type_check" CHECK (("job_type" = 'full_entry')),
    CONSTRAINT "ai_analysis_jobs_status_check" CHECK (("status" = ANY (ARRAY['queued'::"text", 'processing'::"text", 'completed'::"text", 'failed'::"text", 'cancelled'::"text"])))
);

CREATE INDEX IF NOT EXISTS "idx_ai_analysis_jobs_status_created"
  ON "public"."ai_analysis_jobs" ("status", "created_at");

CREATE INDEX IF NOT EXISTS "idx_ai_analysis_jobs_entry_id"
  ON "public"."ai_analysis_jobs" ("entry_id");
