import { DiaryEntryModel } from '../models/DiaryEntry';
import Database from '../services/database';

jest.mock('../services/database', () => ({
  __esModule: true,
  default: {
    query: jest.fn(),
  },
}));

const mockedQuery = Database.query as jest.MockedFunction<typeof Database.query>;

function diaryRow(blocks: any[]) {
  return {
    rows: [
      {
        id: 'entry-1',
        user_id: 'user-1',
        date: '2026-05-18',
        content: 'meal',
        blocks,
        total_calories: 0,
        total_protein: 0,
        total_fat: 0,
        total_carbs: 0,
        total_fiber: 0,
        total_sugar: 0,
        total_sodium: 0,
        ai_analysis_status: 'completed',
        ai_analysis_error: null,
        ai_analysis_job_id: null,
        ai_analysis_requested_at: null,
        images: [],
        created_at: '2026-05-18T10:00:00Z',
        updated_at: '2026-05-18T10:00:00Z',
      },
    ],
    rowCount: 1,
    command: 'SELECT',
    oid: 0,
    fields: [],
  };
}

function getUpdateBlocksArg(): any[] {
  const updateCall = mockedQuery.mock.calls.find(([sql]) =>
    typeof sql === 'string' && sql.includes('UPDATE diary_entries')
  );
  if (!updateCall) throw new Error('No UPDATE call recorded');
  const params = updateCall[1] as any[];
  return JSON.parse(params[1]);
}

describe('DiaryEntryModel.updateContentAndBlocks defensive dedup', () => {
  beforeEach(() => {
    mockedQuery.mockReset();
  });

  it('drops duplicate blocks with the same normalized content (different ids)', async () => {
    const existingBlocks = [
      { id: 'p1', position: 1, content: 'write what you ate today' },
      { id: 'old-yogurt', stableId: 'sA', position: 2, content: 'Greek yogurt', calories: 150, protein: 15 },
    ];
    mockedQuery
      .mockResolvedValueOnce(diaryRow(existingBlocks)) // getById
      .mockResolvedValueOnce(diaryRow([])); // UPDATE

    const incoming = [
      { id: 'p1', position: 1, content: 'write what you ate today' },
      { id: 'new-yogurt-1', stableId: 'sA', position: 2, content: 'Greek yogurt' },
      // Same food, different stableId & id — classic state-drift dup
      { id: 'new-yogurt-2', stableId: 'sB', position: 3, content: 'Greek yogurt' },
    ];

    await DiaryEntryModel.updateContentAndBlocks('entry-1', 'user-1', 'meal', incoming);

    const written = getUpdateBlocksArg();
    expect(written).toHaveLength(2);
    expect(written[0].content).toBe('write what you ate today');
    expect(written[1].content).toBe('Greek yogurt');
    // Preserved nutrition from the existing block
    expect(written[1].calories).toBe(150);
    expect(written[1].protein).toBe(15);
  });

  it('prefers userModified=true on collision', async () => {
    mockedQuery
      .mockResolvedValueOnce(diaryRow([])) // no existing
      .mockResolvedValueOnce(diaryRow([]));

    const incoming = [
      { id: 'a', position: 1, content: 'pasta', calories: 600 },
      { id: 'b', position: 2, content: 'pasta', calories: 450, userModified: true },
    ];

    await DiaryEntryModel.updateContentAndBlocks('entry-1', 'user-1', 'meal', incoming);

    const written = getUpdateBlocksArg();
    expect(written).toHaveLength(1);
    expect(written[0].calories).toBe(450);
    expect(written[0].userModified).toBe(true);
    expect(written[0].position).toBe(1); // position of the original collision target
  });

  it('treats stableId collision as duplicate even if content differs slightly', async () => {
    mockedQuery
      .mockResolvedValueOnce(diaryRow([]))
      .mockResolvedValueOnce(diaryRow([]));

    const incoming = [
      { id: 'a', stableId: 'X', position: 1, content: 'eggs', calories: 200 },
      { id: 'b', stableId: 'X', position: 2, content: 'two eggs', calories: 220 },
    ];

    await DiaryEntryModel.updateContentAndBlocks('entry-1', 'user-1', 'meal', incoming);

    const written = getUpdateBlocksArg();
    expect(written).toHaveLength(1);
  });

  it('does not dedupe the position-1 placeholder', async () => {
    mockedQuery
      .mockResolvedValueOnce(diaryRow([]))
      .mockResolvedValueOnce(diaryRow([]));

    const incoming = [
      { id: 'p1', position: 1, content: 'write what you ate today' },
      { id: 'a', position: 2, content: 'eggs' },
      { id: 'b', position: 3, content: 'toast' },
    ];

    await DiaryEntryModel.updateContentAndBlocks('entry-1', 'user-1', 'meal', incoming);

    const written = getUpdateBlocksArg();
    expect(written).toHaveLength(3);
  });

  it('passes through clean (no-collision) inputs untouched', async () => {
    mockedQuery
      .mockResolvedValueOnce(diaryRow([]))
      .mockResolvedValueOnce(diaryRow([]));

    const incoming = [
      { id: 'a', position: 1, content: 'eggs' },
      { id: 'b', position: 2, content: 'toast' },
      { id: 'c', position: 3, content: 'coffee' },
    ];

    await DiaryEntryModel.updateContentAndBlocks('entry-1', 'user-1', 'meal', incoming);

    const written = getUpdateBlocksArg();
    expect(written).toHaveLength(3);
    expect(written.map((b: any) => b.content)).toEqual(['eggs', 'toast', 'coffee']);
  });

  it('renumbers positions contiguously after dropping duplicates', async () => {
    mockedQuery
      .mockResolvedValueOnce(diaryRow([]))
      .mockResolvedValueOnce(diaryRow([]));

    const incoming = [
      { id: 'p1', position: 1, content: 'write what you ate today' },
      { id: 'a', position: 2, content: 'eggs' },
      { id: 'b', position: 3, content: 'eggs' }, // dup, dropped
      { id: 'c', position: 4, content: 'toast' },
    ];

    await DiaryEntryModel.updateContentAndBlocks('entry-1', 'user-1', 'meal', incoming);

    const written = getUpdateBlocksArg();
    expect(written.map((b: any) => b.position)).toEqual([1, 2, 3]);
  });
});
