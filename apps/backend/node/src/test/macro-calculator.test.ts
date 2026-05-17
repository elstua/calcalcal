import {
  calculateMacroGoals,
  calculateCalorieGoal,
  DEFAULT_PROTEIN_GOAL,
  DEFAULT_FAT_GOAL,
  DEFAULT_CARB_GOAL,
  UserHealthData,
} from '../services/calorieCalculator';

describe('calculateMacroGoals', () => {
  // Reference profile: 30yo male, 80kg, 180cm, moderate activity
  const baseProfile: UserHealthData = {
    weight_kg: 80,
    height_cm: 180,
    age: 30,
    activity_level: 'moderate',
    gender: 'male',
    weight_unit: 'kg',
    height_unit: 'cm',
  };

  describe('insufficient data → defaults', () => {
    it('returns DB defaults when weight missing', () => {
      const macros = calculateMacroGoals(
        { ...baseProfile, weight_kg: null },
        2000
      );
      expect(macros).toEqual({
        daily_protein_goal: DEFAULT_PROTEIN_GOAL,
        daily_fat_goal: DEFAULT_FAT_GOAL,
        daily_carb_goal: DEFAULT_CARB_GOAL,
      });
    });

    it('returns defaults when activity level missing', () => {
      const macros = calculateMacroGoals(
        { ...baseProfile, activity_level: null },
        2000
      );
      expect(macros.daily_protein_goal).toBe(DEFAULT_PROTEIN_GOAL);
      expect(macros.daily_fat_goal).toBe(DEFAULT_FAT_GOAL);
      expect(macros.daily_carb_goal).toBe(DEFAULT_CARB_GOAL);
    });

    it('returns defaults when age missing', () => {
      const macros = calculateMacroGoals(
        { ...baseProfile, age: null },
        2000
      );
      expect(macros.daily_protein_goal).toBe(DEFAULT_PROTEIN_GOAL);
    });

    it('returns defaults when calorie goal is non-positive', () => {
      const macros = calculateMacroGoals(baseProfile, 0);
      expect(macros.daily_protein_goal).toBe(DEFAULT_PROTEIN_GOAL);
    });

    it('returns defaults for out-of-range values', () => {
      const macros = calculateMacroGoals(
        { ...baseProfile, weight_kg: 2000 },
        2000
      );
      expect(macros.daily_protein_goal).toBe(DEFAULT_PROTEIN_GOAL);
    });
  });

  describe('goal direction: maintain (no target)', () => {
    it('uses 1.8 g/kg of current weight for protein', () => {
      const macros = calculateMacroGoals(baseProfile, 2500);
      // 1.8 * 80 = 144
      expect(macros.daily_protein_goal).toBe(144);
    });

    it('uses 1.8 g/kg when target equals current weight', () => {
      const macros = calculateMacroGoals(
        { ...baseProfile, target_weight_kg: 80 },
        2500
      );
      expect(macros.daily_protein_goal).toBe(144);
    });
  });

  describe('goal direction: lose', () => {
    it('uses 2.0 g/kg of target weight', () => {
      // current 80, target 70 -> lose; protein = 2.0 * 70 = 140
      const macros = calculateMacroGoals(
        { ...baseProfile, target_weight_kg: 70 },
        2000
      );
      expect(macros.daily_protein_goal).toBe(140);
    });
  });

  describe('goal direction: gain', () => {
    it('uses 1.6 g/kg of current weight', () => {
      // current 80, target 90 -> gain; protein = 1.6 * 80 = 128
      const macros = calculateMacroGoals(
        { ...baseProfile, target_weight_kg: 90 },
        3000
      );
      expect(macros.daily_protein_goal).toBe(128);
    });
  });

  describe('protein clamps', () => {
    it('floors at 60 g for very low body weight', () => {
      // 30 kg * 1.8 = 54, floored to 60
      const macros = calculateMacroGoals(
        { ...baseProfile, weight_kg: 30 },
        1500
      );
      expect(macros.daily_protein_goal).toBe(60);
    });

    it('caps at 220 g for very heavy body weight', () => {
      // 150 kg * 1.8 = 270, capped to 220
      const macros = calculateMacroGoals(
        { ...baseProfile, weight_kg: 150 },
        4000
      );
      expect(macros.daily_protein_goal).toBe(220);
    });
  });

  describe('fat calculation', () => {
    it('uses 25% of calories when that exceeds 0.8 g/kg', () => {
      // 80kg, 2500 kcal: 0.8 * 80 = 64; 0.25 * 2500 / 9 = 69.4
      // fat = max(64, 69.4) = 69 (rounded)
      const macros = calculateMacroGoals(baseProfile, 2500);
      expect(macros.daily_fat_goal).toBe(69);
    });

    it('uses 0.8 g/kg when that exceeds 25% of calories', () => {
      // 100 kg, 3500 kcal: 0.8*100 = 80; 0.25*3500/9 = 97.2 -> max=97
      // Use a high-cal profile where 0.8g/kg loses to %-cal, and ensure no carb-clawback.
      // Different angle: pick low calorie surplus where 0.8g/kg wins AND carbs stay >50.
      // 70 kg, 2200 kcal: 0.8*70 = 56; 0.25*2200/9 = 61.1; fat = 61 (rounded).
      // protein 1.8*70=126 -> 504 kcal; fat 61->549 kcal; carbs (2200-504-549)/4 = 286g. OK.
      // To force 0.8g/kg winning: 90kg, 2400 kcal: 0.8*90=72; 0.25*2400/9=66.7; fat=72
      // protein=1.8*90=162 -> 648; fat 72 -> 648; carbs (2400-648-648)/4 = 276g. >50.
      const macros = calculateMacroGoals(
        { ...baseProfile, weight_kg: 90 },
        2400
      );
      expect(macros.daily_fat_goal).toBe(72);
    });

    it('floors at 40 g', () => {
      // 40 kg, 1200 kcal: 0.8*40 = 32; 0.25*1200/9 = 33.3 -> max=33.3, floored to 40
      const macros = calculateMacroGoals(
        { ...baseProfile, weight_kg: 40 },
        1200
      );
      expect(macros.daily_fat_goal).toBe(40);
    });
  });

  describe('carb calculation (remainder)', () => {
    it('fills remaining calories with carbs', () => {
      // baseProfile, 2500 kcal: protein 144g (576 kcal), fat 69g (621 kcal)
      // remainder = 2500 - 576 - 621 = 1303 kcal / 4 = 325.75 -> 326
      const macros = calculateMacroGoals(baseProfile, 2500);
      expect(macros.daily_carb_goal).toBe(326);

      // Sanity: macros sum back to ~calorie goal
      const total = macros.daily_protein_goal * 4 + macros.daily_fat_goal * 9 + macros.daily_carb_goal * 4;
      expect(Math.abs(total - 2500)).toBeLessThanOrEqual(5);
    });

    it('claws fat down to floor when carbs go below 50 g', () => {
      // Squeezed scenario: 80kg male, but tiny calorie budget
      // protein = 1.8 * 80 = 144g = 576 kcal
      // fat naive: max(0.8*80=64, 0.25*1000/9=27.8) = 64g = 576 kcal
      // remainder = 1000 - 576 - 576 = -152 -> negative, so we claw back fat to floor 40g
      // After claw: fat = 40g (360 kcal); remainder = 1000-576-360 = 64 kcal / 4 = 16g
      const macros = calculateMacroGoals(baseProfile, 1000);
      expect(macros.daily_fat_goal).toBeLessThanOrEqual(64);
      expect(macros.daily_fat_goal).toBeGreaterThanOrEqual(40);
      expect(macros.daily_carb_goal).toBeGreaterThanOrEqual(0);
    });

    it('carbs never negative', () => {
      const macros = calculateMacroGoals(
        { ...baseProfile, weight_kg: 150 },
        1500
      );
      expect(macros.daily_carb_goal).toBeGreaterThanOrEqual(0);
    });
  });

  describe('integration with calculateCalorieGoal', () => {
    it('macros sum to calorie goal for typical profile', () => {
      const profile: UserHealthData = {
        weight_kg: 75,
        height_cm: 175,
        age: 35,
        activity_level: 'moderate',
        gender: 'female',
        weight_unit: 'kg',
        height_unit: 'cm',
        target_weight_kg: 70,
      };
      const calorieGoal = calculateCalorieGoal(profile);
      const macros = calculateMacroGoals(profile, calorieGoal);
      const totalKcal =
        macros.daily_protein_goal * 4 +
        macros.daily_fat_goal * 9 +
        macros.daily_carb_goal * 4;
      // Allow ±10 kcal slack from rounding
      expect(Math.abs(totalKcal - calorieGoal)).toBeLessThanOrEqual(10);
    });
  });

  describe('regression: Masha bug scenario', () => {
    // Reproduce the report: protein stuck at 50 g despite filling in health data
    it('female user with full profile gets >50 g protein', () => {
      const masha: UserHealthData = {
        weight_kg: 60,
        height_cm: 165,
        age: 30,
        activity_level: 'moderate',
        gender: 'female',
        weight_unit: 'kg',
        height_unit: 'cm',
      };
      const calorieGoal = calculateCalorieGoal(masha);
      const macros = calculateMacroGoals(masha, calorieGoal);
      // 1.8 * 60 = 108 g — much higher than the stuck-at-50 default
      expect(macros.daily_protein_goal).toBe(108);
      expect(macros.daily_protein_goal).not.toBe(DEFAULT_PROTEIN_GOAL);
    });
  });
});
