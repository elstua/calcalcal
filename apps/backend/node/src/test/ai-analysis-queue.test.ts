import { AIAnalysisJobModel } from "../models/AIAnalysisJob";
import Database from "../services/database";

jest.mock("../services/database", () => ({
  __esModule: true,
  default: {
    query: jest.fn(),
  },
}));

const mockedQuery = Database.query as jest.MockedFunction<typeof Database.query>;

describe("AIAnalysisJobModel", () => {
  beforeEach(() => {
    mockedQuery.mockClear();
    mockedQuery.mockResolvedValue({
      rows: [],
      rowCount: 0,
      command: "SELECT",
      oid: 0,
      fields: [],
    });
  });

  it("enqueues full-entry jobs with serialized blocks", async () => {
    await AIAnalysisJobModel.enqueueFullEntry({
      jobId: "job-1",
      entryId: "entry-1",
      userId: "user-1",
      entryDate: "2026-05-02",
      blocks: [{ id: "block-1", content: "eggs" }],
    });

    const [sql, params] = mockedQuery.mock.calls[0];
    expect(sql).toContain("INSERT INTO ai_analysis_jobs");
    expect(params).toEqual([
      "job-1",
      "entry-1",
      "user-1",
      "2026-05-02",
      JSON.stringify([{ id: "block-1", content: "eggs" }]),
    ]);
  });

  it("claims queued jobs with row locking and stale processing recovery", async () => {
    await AIAnalysisJobModel.claimNext("worker-1", 300);

    const [sql, params] = mockedQuery.mock.calls[0];
    expect(sql).toContain("FOR UPDATE SKIP LOCKED");
    expect(sql).toContain("status = 'queued'");
    expect(sql).toContain("status = 'processing'");
    expect(sql).toContain("locked_at < NOW() - ($1::int * INTERVAL '1 second')");
    expect(sql).toContain("RETURNING");
    expect(sql).toContain("jobs.id");
    expect(params).toEqual([300, "worker-1"]);
  });

  it("detects a missing queue table error", () => {
    expect(AIAnalysisJobModel.isMissingJobsTableError({ code: "42P01" })).toBe(
      true,
    );
    expect(AIAnalysisJobModel.isMissingJobsTableError({ code: "23505" })).toBe(
      false,
    );
    expect(AIAnalysisJobModel.isMissingJobsTableError(null)).toBe(false);
  });
});
