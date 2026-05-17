-- Migration 014: Backfill macro goals (protein / fat / carbs) for existing users.
--
-- Replicates the logic in src/services/calorieCalculator.ts → calculateMacroGoals.
-- Users with incomplete health data keep their existing values (which default to
-- 50/65/250 from migration 001), matching the "fall back to defaults" rule in code.
--
-- Protein:
--   lose     → 2.0 g/kg target_weight_kg
--   gain     → 1.6 g/kg weight_kg
--   maintain → 1.8 g/kg weight_kg
--   clamped [60, 220]
-- Fat:
--   max(0.8 * weight_kg, 0.25 * daily_calorie_goal / 9), floored at 40
-- Carbs:
--   (daily_calorie_goal - protein*4 - fat*9) / 4
--   If <50g, fat is trimmed down to its 40 g floor first; carbs then floored at 0.

WITH normalized AS (
  SELECT
    id,
    daily_calorie_goal,
    -- weight in kg (DB column is already kg per model definition, but unit hint exists)
    CASE
      WHEN weight_unit = 'lbs' THEN weight_kg * 0.453592
      ELSE weight_kg
    END AS w_kg,
    CASE
      WHEN height_unit = 'in' THEN height_cm * 2.54
      ELSE height_cm
    END AS h_cm,
    age,
    activity_level,
    target_weight_kg AS t_kg
  FROM user_profiles
  WHERE
    weight_kg IS NOT NULL AND weight_kg > 0 AND weight_kg <= 1000
    AND height_cm IS NOT NULL AND height_cm > 0 AND height_cm <= 300
    AND age IS NOT NULL AND age > 0 AND age <= 150
    AND activity_level IS NOT NULL
    AND daily_calorie_goal IS NOT NULL AND daily_calorie_goal > 0
),
protein_calc AS (
  SELECT
    id,
    daily_calorie_goal,
    w_kg,
    LEAST(220, GREATEST(60, ROUND(
      CASE
        WHEN t_kg IS NOT NULL AND t_kg < w_kg THEN 2.0 * t_kg          -- lose
        WHEN t_kg IS NOT NULL AND t_kg > w_kg THEN 1.6 * w_kg          -- gain
        ELSE 1.8 * w_kg                                                -- maintain
      END
    )))::numeric AS protein_g
  FROM normalized
),
fat_naive AS (
  SELECT
    p.id,
    p.daily_calorie_goal,
    p.w_kg,
    p.protein_g,
    GREATEST(40, ROUND(
      GREATEST(0.8 * p.w_kg, 0.25 * p.daily_calorie_goal / 9.0)
    ))::numeric AS fat_g_naive
  FROM protein_calc p
),
trimmed AS (
  SELECT
    id,
    daily_calorie_goal,
    protein_g,
    fat_g_naive,
    -- Naive carb kcal remainder
    (daily_calorie_goal - protein_g * 4 - fat_g_naive * 9) AS carb_kcal_naive
  FROM fat_naive
),
final_macros AS (
  SELECT
    id,
    protein_g,
    -- If naive carbs < 50 g (i.e. carb_kcal_naive < 200), trim fat down to floor 40
    CASE
      WHEN carb_kcal_naive / 4.0 < 50 THEN
        GREATEST(
          40,
          ROUND(fat_g_naive - LEAST(
            (fat_g_naive - 40) * 9,                       -- kcal available to trim
            (50 - carb_kcal_naive / 4.0) * 4              -- kcal needed for carbs to hit 50
          ) / 9.0)
        )
      ELSE fat_g_naive
    END AS fat_g,
    daily_calorie_goal
  FROM trimmed
),
final_with_carbs AS (
  SELECT
    id,
    protein_g,
    fat_g,
    GREATEST(0, ROUND((daily_calorie_goal - protein_g * 4 - fat_g * 9) / 4.0))::numeric AS carb_g
  FROM final_macros
)
UPDATE user_profiles up
SET
  daily_protein_goal = fm.protein_g,
  daily_fat_goal = fm.fat_g,
  daily_carb_goal = fm.carb_g,
  updated_at = NOW()
FROM final_with_carbs fm
WHERE up.id = fm.id
  -- Idempotency guard: only backfill rows still at the original migration-001 defaults.
  -- After this migration runs once, recomputed values won't match (50,65,250), so reruns
  -- are no-ops. Users who manually edited their macros via the API are also untouched.
  AND up.daily_protein_goal = 50
  AND up.daily_fat_goal = 65
  AND up.daily_carb_goal = 250;
