/**
 * Calorie Calculator Service
 *
 * Calculates daily calorie needs using the Mifflin-St Jeor equation for BMR
 * and Legion-adjusted activity multipliers for TDEE (Total Daily Energy Expenditure).
 *
 * All calculations use metric units internally (kg for weight, cm for height).
 */

export type ActivityLevel = 'sedentary' | 'light' | 'moderate' | 'active' | 'very_active' | 'small';
export type Gender = 'male' | 'female' | 'other' | null;

export interface UserHealthData {
  weight_kg?: number | null;
  height_cm?: number | null;
  age?: number | null;
  activity_level?: ActivityLevel | null;
  gender?: Gender;
  weight_unit?: 'kg' | 'lbs';
  height_unit?: 'cm' | 'in';
  target_weight_kg?: number | null;
}

/**
 * Legion-adjusted activity multipliers for TDEE calculation.
 * These are lower than the classic Harris-Benedict values to better reflect
 * real-world energy expenditure (NEAT variance, desk jobs, etc.).
 */
const ACTIVITY_MULTIPLIERS: Record<ActivityLevel, number> = {
  sedentary: 1.15,    // Little or no exercise, desk job
  light: 1.35,        // Light exercise 1-3 days/week
  moderate: 1.50,     // Moderate exercise 3-5 days/week
  active: 1.60,       // Hard exercise 6-7 days/week
  very_active: 1.80,  // Intense exercise or physical job
  small: 1.15,        // Legacy value, maps to sedentary
};

/**
 * Default calorie goal when insufficient data is available
 */
const DEFAULT_CALORIE_GOAL = 2000;

/**
 * Convert pounds to kilograms
 */
export function lbsToKg(lbs: number): number {
  return lbs * 0.453592;
}

/**
 * Convert kilograms to pounds
 */
export function kgToLbs(kg: number): number {
  return kg * 2.20462;
}

/**
 * Convert inches to centimeters
 */
export function inchesToCm(inches: number): number {
  return inches * 2.54;
}

/**
 * Convert centimeters to inches
 */
export function cmToInches(cm: number): number {
  return cm / 2.54;
}

/**
 * Normalize weight to kilograms
 */
function normalizeWeight(weight: number, unit: 'kg' | 'lbs' = 'kg'): number {
  return unit === 'lbs' ? lbsToKg(weight) : weight;
}

/**
 * Normalize height to centimeters
 */
function normalizeHeight(height: number, unit: 'cm' | 'in' = 'cm'): number {
  return unit === 'in' ? inchesToCm(height) : height;
}

/**
 * Calculate Basal Metabolic Rate (BMR) using Mifflin-St Jeor equation
 *
 * Men: BMR = (10 x weight_kg) + (6.25 x height_cm) - (5 x age) + 5
 * Women: BMR = (10 x weight_kg) + (6.25 x height_cm) - (5 x age) - 161
 * Other/Unknown: Average of male and female formulas
 */
export function calculateBMR(
  weight_kg: number,
  height_cm: number,
  age: number,
  gender: Gender
): number {
  const baseBMR = (10 * weight_kg) + (6.25 * height_cm) - (5 * age);

  if (gender === 'male') {
    return baseBMR + 5;
  } else if (gender === 'female') {
    return baseBMR - 161;
  } else {
    // For 'other' or null, use average of male and female formulas
    const maleBMR = baseBMR + 5;
    const femaleBMR = baseBMR - 161;
    return (maleBMR + femaleBMR) / 2;
  }
}

/**
 * Calculate Total Daily Energy Expenditure (TDEE)
 * TDEE = BMR x activity multiplier
 */
export function calculateTDEE(bmr: number, activityLevel: ActivityLevel): number {
  const multiplier = ACTIVITY_MULTIPLIERS[activityLevel];
  return bmr * multiplier;
}

/**
 * Get the minimum safe calorie floor based on gender
 */
function getMinCalories(gender: Gender): number {
  if (gender === 'female') return 1200;
  if (gender === 'male') return 1500;
  return 1350;
}

/**
 * Calculate daily calorie goal based on user health data
 *
 * Returns DEFAULT_CALORIE_GOAL (2000 kcal) if insufficient data is available.
 *
 * Applies percentage-based deficit/surplus based on weight vs target weight:
 * - Lose (target < current): TDEE x 0.80 (-20%)
 * - Gain (target > current): TDEE x 1.10 (+10%)
 * - Maintain (target == current or no target): TDEE x 1.0
 *
 * Enforces a safety floor: 1200 kcal (female), 1500 kcal (male), 1350 kcal (other).
 */
export function calculateCalorieGoal(userData: UserHealthData): number {
  // Extract and normalize weight
  let weight_kg: number | null = null;
  if (userData.weight_kg !== null && userData.weight_kg !== undefined) {
    weight_kg = normalizeWeight(
      userData.weight_kg,
      userData.weight_unit || 'kg'
    );
  }

  // Extract and normalize height
  let height_cm: number | null = null;
  if (userData.height_cm !== null && userData.height_cm !== undefined) {
    height_cm = normalizeHeight(
      userData.height_cm,
      userData.height_unit || 'cm'
    );
  }

  // Check if we have minimum required data
  if (
    weight_kg === null ||
    height_cm === null ||
    userData.age === null ||
    userData.age === undefined ||
    !userData.activity_level
  ) {
    return DEFAULT_CALORIE_GOAL;
  }

  // Validate data ranges (basic sanity checks)
  if (weight_kg <= 0 || weight_kg > 1000) {
    return DEFAULT_CALORIE_GOAL;
  }
  if (height_cm <= 0 || height_cm > 300) {
    return DEFAULT_CALORIE_GOAL;
  }
  if (userData.age <= 0 || userData.age > 150) {
    return DEFAULT_CALORIE_GOAL;
  }

  // Calculate BMR
  const gender = userData.gender || null;
  const bmr = calculateBMR(weight_kg, height_cm, userData.age, gender);

  // Calculate TDEE
  const tdee = calculateTDEE(bmr, userData.activity_level);

  // Apply goal-based adjustment (deficit/surplus)
  let goalMultiplier = 1.0;
  if (
    userData.target_weight_kg !== null &&
    userData.target_weight_kg !== undefined &&
    weight_kg !== null
  ) {
    if (userData.target_weight_kg < weight_kg) {
      goalMultiplier = 0.80; // -20% for weight loss
    } else if (userData.target_weight_kg > weight_kg) {
      goalMultiplier = 1.10; // +10% for weight gain
    }
  }

  let goal = Math.round(tdee * goalMultiplier);

  // Enforce safety floor
  const minCalories = getMinCalories(gender);
  goal = Math.max(goal, minCalories);

  return goal;
}
