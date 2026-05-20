import express from 'express';
import request from 'supertest';

import streaksRoutes from '../routes/streaks';
import { DiaryEntryModel } from '../models/DiaryEntry';
import { StreaksModel } from '../models/Streaks';
import { StreakCalculator } from '../services/streakCalculator';

jest.mock('../middleware/auth', () => ({
  authenticateToken: (req: any, _res: any, next: any) => {
    req.userId = 'user-1';
    next();
  },
}));

jest.mock('../models/Streaks', () => ({
  StreaksModel: {
    getStreaksData: jest.fn(),
  },
}));

jest.mock('../models/DiaryEntry', () => ({
  DiaryEntryModel: {
    listAnalyzedByDateRange: jest.fn(),
  },
}));

jest.mock('../services/streakCalculator', () => ({
  StreakCalculator: {
    getTimezoneAwareDate: jest.fn((timestamp: Date, timezoneOffset: number) => {
      const adjustedDate = new Date(timestamp.getTime() + timezoneOffset * 60 * 1000);
      return adjustedDate.toISOString().split('T')[0];
    }),
    getUserTimezoneOffset: jest.fn(),
    initializeUserStreaks: jest.fn(),
    recalculateAllStreaks: jest.fn(),
  },
}));

const app = express();
app.use('/api/streaks', streaksRoutes);

describe('GET /api/streaks staleness check', () => {
  beforeEach(() => {
    jest.useFakeTimers().setSystemTime(new Date('2026-05-20T12:00:00.000Z'));
    jest.clearAllMocks();
    (DiaryEntryModel.listAnalyzedByDateRange as jest.Mock).mockResolvedValue([]);
    (StreakCalculator.getUserTimezoneOffset as jest.Mock).mockResolvedValue(60);
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('treats a Date-typed lastEntryDate for today as recent', async () => {
    (StreaksModel.getStreaksData as jest.Mock).mockResolvedValue({
      currentStreak: 1,
      longestStreak: 3,
      totalDaysWithEntries: 12,
      lastEntryDate: new Date(2026, 4, 20),
      streakStartDate: '2026-05-20',
    });

    const response = await request(app).get('/api/streaks').expect(200);

    expect(response.body.currentStreak).toBe(1);
    expect(StreakCalculator.initializeUserStreaks).not.toHaveBeenCalled();
    expect(StreakCalculator.recalculateAllStreaks).not.toHaveBeenCalled();
  });
});
