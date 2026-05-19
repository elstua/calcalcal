jest.mock('../services/database', () => ({
  __esModule: true,
  default: {
    query: jest.fn(),
  },
}));

import Database from '../services/database';
import { User, UserModel } from '../models/User';
import { calculateCalorieGoal } from '../services/calorieCalculator';

const mockQuery = Database.query as jest.Mock;

const baseUser: User = {
  id: 'user-1',
  email: null,
  name: null,
  apple_id: null,
  google_id: null,
  daily_calorie_goal: 2100,
  daily_calorie_goal_is_manual: false,
  daily_protein_goal: 120,
  daily_fat_goal: 65,
  daily_carb_goal: 240,
  units: 'kcal',
  timezone_offset: 0,
  weight_kg: 80,
  height_cm: 180,
  age: 30,
  activity_level: 'moderate',
  target_weight_kg: 75,
  gender: 'male',
  weight_unit: 'kg',
  height_unit: 'cm',
  onboarding_completed: true,
  is_temporary: false,
  device_id: null,
  created_via: 'temporary',
  created_at: '2026-01-01T00:00:00.000Z',
  updated_at: '2026-01-01T00:00:00.000Z',
};

describe('UserModel calorie goal source', () => {
  beforeEach(() => {
    mockQuery.mockReset();
  });

  it('keeps a manual calorie goal when health fields change', async () => {
    const existing = {
      ...baseUser,
      daily_calorie_goal: 2300,
      daily_calorie_goal_is_manual: true,
    };
    mockQuery
      .mockResolvedValueOnce({ rows: [existing] })
      .mockResolvedValueOnce({ rows: [{ ...existing, weight_kg: 82 }] });

    await UserModel.update(existing.id, { weight_kg: 82 });

    const [updateSql, updateParams] = mockQuery.mock.calls[1];
    expect(updateSql).not.toContain('daily_calorie_goal =');
    expect(updateSql).not.toContain('daily_calorie_goal_is_manual =');
    expect(updateParams).toContain(82);
    expect(updateParams).not.toContain(calculateCalorieGoal({ ...existing, weight_kg: 82 }));
  });

  it('marks calorie goal updates as manual unless the caller says otherwise', async () => {
    mockQuery
      .mockResolvedValueOnce({ rows: [baseUser] })
      .mockResolvedValueOnce({ rows: [{ ...baseUser, daily_calorie_goal: 2400 }] });

    await UserModel.update(baseUser.id, { daily_calorie_goal: 2400 });

    const [updateSql, updateParams] = mockQuery.mock.calls[1];
    expect(updateSql).toContain('daily_calorie_goal =');
    expect(updateSql).toContain('daily_calorie_goal_is_manual =');
    expect(updateParams).toContain(2400);
    expect(updateParams).toContain(true);
  });

  it('recalculates the goal when resetting from manual to calculated', async () => {
    const existing = {
      ...baseUser,
      daily_calorie_goal: 2400,
      daily_calorie_goal_is_manual: true,
    };
    const expectedCalculatedGoal = calculateCalorieGoal(existing);
    mockQuery
      .mockResolvedValueOnce({ rows: [existing] })
      .mockResolvedValueOnce({
        rows: [
          {
            ...existing,
            daily_calorie_goal: expectedCalculatedGoal,
            daily_calorie_goal_is_manual: false,
          },
        ],
      });

    await UserModel.update(existing.id, { daily_calorie_goal_is_manual: false });

    const [updateSql, updateParams] = mockQuery.mock.calls[1];
    expect(updateSql).toContain('daily_calorie_goal_is_manual =');
    expect(updateSql).toContain('daily_calorie_goal =');
    expect(updateParams).toContain(false);
    expect(updateParams).toContain(expectedCalculatedGoal);
  });
});
