import { calculateMacroCorridor } from '../services/calorieCalculator';

describe('calculateMacroCorridor', () => {
  it('computes ±25%/-10% for protein, ±20% fat, ±15% carb, ±10% calories', () => {
    const r = calculateMacroCorridor({
      daily_calorie_goal: 2000,
      daily_protein_goal: 100,
      daily_fat_goal: 60,
      daily_carb_goal: 200,
    });
    // protein 100 -> 90..125
    expect(r.daily_protein_range).toEqual({ min: 90, max: 125 });
    // fat 60 -> 48..72
    expect(r.daily_fat_range).toEqual({ min: 48, max: 72 });
    // carb 200 -> 170..230
    expect(r.daily_carb_range).toEqual({ min: 170, max: 230 });
    // calories 2000 -> 1800..2200 (10%=200 > minBand 100)
    expect(r.daily_calorie_range).toEqual({ min: 1800, max: 2200 });
  });

  it('enforces minBand=100 on small calorie goals', () => {
    // 800 kcal: 10% = 80; band should expand to 100
    const r = calculateMacroCorridor({
      daily_calorie_goal: 800,
      daily_protein_goal: 60,
      daily_fat_goal: 40,
      daily_carb_goal: 80,
    });
    expect(r.daily_calorie_range).toEqual({ min: 700, max: 900 });
  });

  it('floors at zero for tiny goals', () => {
    const r = calculateMacroCorridor({
      daily_calorie_goal: 100,
      daily_protein_goal: 0,
      daily_fat_goal: 0,
      daily_carb_goal: 0,
    });
    expect(r.daily_protein_range.min).toBe(0);
    expect(r.daily_fat_range.min).toBe(0);
    expect(r.daily_carb_range.min).toBe(0);
    expect(r.daily_calorie_range.min).toBe(0);
  });

  it('handles Masha-shaped real values', () => {
    // Real backfilled values: 1675 kcal / 106p / 47f / 207c
    const r = calculateMacroCorridor({
      daily_calorie_goal: 1675,
      daily_protein_goal: 106,
      daily_fat_goal: 47,
      daily_carb_goal: 207,
    });
    expect(r.daily_protein_range).toEqual({ min: 95, max: 133 });
    expect(r.daily_fat_range).toEqual({ min: 38, max: 56 });
    expect(r.daily_carb_range).toEqual({ min: 176, max: 238 });
    expect(r.daily_calorie_range).toEqual({ min: 1507, max: 1843 });
  });

  it('range always contains the goal value', () => {
    const goals = {
      daily_calorie_goal: 2200,
      daily_protein_goal: 130,
      daily_fat_goal: 70,
      daily_carb_goal: 260,
    };
    const r = calculateMacroCorridor(goals);
    expect(r.daily_protein_range.min).toBeLessThanOrEqual(goals.daily_protein_goal);
    expect(r.daily_protein_range.max).toBeGreaterThanOrEqual(goals.daily_protein_goal);
    expect(r.daily_fat_range.min).toBeLessThanOrEqual(goals.daily_fat_goal);
    expect(r.daily_fat_range.max).toBeGreaterThanOrEqual(goals.daily_fat_goal);
    expect(r.daily_carb_range.min).toBeLessThanOrEqual(goals.daily_carb_goal);
    expect(r.daily_carb_range.max).toBeGreaterThanOrEqual(goals.daily_carb_goal);
    expect(r.daily_calorie_range.min).toBeLessThanOrEqual(goals.daily_calorie_goal);
    expect(r.daily_calorie_range.max).toBeGreaterThanOrEqual(goals.daily_calorie_goal);
  });
});
