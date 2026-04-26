import { DiaryEntryModel } from '../models/DiaryEntry';
import Database from '../services/database';

jest.mock('../services/database', () => ({
  __esModule: true,
  default: {
    query: jest.fn(),
  },
}));

const mockedQuery = Database.query as jest.MockedFunction<typeof Database.query>;

describe('DiaryEntryModel date serialization', () => {
  beforeEach(() => {
    mockedQuery.mockResolvedValue({ rows: [], rowCount: 0, command: 'SELECT', oid: 0, fields: [] });
  });

  it('returns diary dates as plain YYYY-MM-DD strings from reads', async () => {
    await DiaryEntryModel.listByDateRange('user-1', '2026-04-20', '2026-04-26');
    await DiaryEntryModel.getByDate('user-1', '2026-04-26');
    await DiaryEntryModel.getById('entry-1');

    for (const [sql] of mockedQuery.mock.calls) {
      expect(sql).toContain("to_char(date, 'YYYY-MM-DD') AS date");
    }
  });

  it('returns diary dates as plain YYYY-MM-DD strings from writes', async () => {
    await DiaryEntryModel.upsert('user-1', '2026-04-26', 'two scrambled eggs and bacon');
    await DiaryEntryModel.updateContent('entry-1', 'user-1', 'macdonalds burger');
    await DiaryEntryModel.updateContentAndBlocks('entry-1', 'user-1', 'macdonalds burger', []);

    for (const [sql] of mockedQuery.mock.calls) {
      expect(sql).toContain("to_char(date, 'YYYY-MM-DD') AS date");
    }
  });
});
