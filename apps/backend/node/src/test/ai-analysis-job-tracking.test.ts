import { DiaryEntryModel } from "../models/DiaryEntry";
import Database from "../services/database";

jest.mock("../services/database", () => ({
  __esModule: true,
  default: {
    query: jest.fn(),
  },
}));

const mockedQuery = Database.query as jest.MockedFunction<typeof Database.query>;

describe("DiaryEntryModel AI analysis job tracking", () => {
  beforeEach(() => {
    mockedQuery.mockClear();
    mockedQuery.mockResolvedValue({
      rows: [],
      rowCount: 0,
      command: "UPDATE",
      oid: 0,
      fields: [],
    });
  });

  it("stores the latest analysis job id when a job starts", async () => {
    await DiaryEntryModel.startAnalysisJob("entry-1", "user-1", "job-1");

    const [sql, params] = mockedQuery.mock.calls[0];
    expect(sql).toContain("ai_analysis_job_id = $2");
    expect(sql).toContain("ai_analysis_requested_at = NOW()");
    expect(params).toEqual(["processing", "job-1", "entry-1", "user-1"]);
  });

  it("only completes the matching latest analysis job", async () => {
    await DiaryEntryModel.completeAnalysisJob("entry-1", "job-1", [], {
      total_calories: 1,
      total_protein: 2,
      total_fat: 3,
      total_carbs: 4,
      total_fiber: 5,
      total_sugar: 6,
      total_sodium: 7,
    });

    const [sql, params] = mockedQuery.mock.calls[0];
    expect(sql).toContain("WHERE id = $10 AND ai_analysis_job_id = $11");
    expect(params?.[9]).toBe("entry-1");
    expect(params?.[10]).toBe("job-1");
  });

  it("only marks the matching latest analysis job as failed", async () => {
    await DiaryEntryModel.failAnalysisJob("entry-1", "job-1", "provider error");

    const [sql, params] = mockedQuery.mock.calls[0];
    expect(sql).toContain("WHERE id = $3 AND ai_analysis_job_id = $4");
    expect(params).toEqual(["failed", "provider error", "entry-1", "job-1"]);
  });
});
