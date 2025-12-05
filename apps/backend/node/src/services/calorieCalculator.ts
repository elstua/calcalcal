/**
 * Calorie Calculator Service
 * 
 * Calculates daily calorie needs using the Mifflin-St Jeor equation for BMR
 * and activity multipliers for TDEE (Total Daily Energy Expenditure).
 * 
 * All calculations use metric units internally (kg for weight, cm for height).
 */

export type ActivityLevel = 'small' | 'moderate' | 'active';
export type Gender = 'male' | 'female' | 'other' | null;

export interface UserHealthData {
  weight_kg?: number | null;
  height_cm?: number | null;
  age?: number | null;
  activity_level?: ActivityLevel | null;
  gender?: Gender;
  weight_unit?: 'kg' | 'lbs';
  height_unit?: 'cm' | 'in';
}

/**
 * Activity multipliers for TDEE calculation
 */
const ACTIVITY_MULTIPLIERS: Record<ActivityLevel, number> = {
  small: 1.2,      // Sedentary
  moderate: 1.55,  // Moderately active
  active: 1.725,   // Very active
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
 * Men: BMR = (10 × weight_kg) + (6.25 × height_cm) - (5 × age) + 5
 * Women: BMR = (10 × weight_kg) + (6.25 × height_cm) - (5 × age) - 161
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
 * TDEE = BMR × activity multiplier
 */
export function calculateTDEE(bmr: number, activityLevel: ActivityLevel): number {
  const multiplier = ACTIVITY_MULTIPLIERS[activityLevel];
  return bmr * multiplier;
}

/**
 * Calculate daily calorie goal based on user health data
 * 
 * Returns DEFAULT_CALORIE_GOAL (2000 kcal) if insufficient data is available.
 * 
 * Required data for calculation:
 * - weight_kg (or weight in lbs with conversion)
 * - height_cm (or height in inches with conversion)
 * - age
 * - activity_level
 * - gender (optional, defaults to average if not provided)
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
  const bmr = calculateBMR(
    weight_kg,
    height_cm,
    userData.age,
    userData.gender || null
  );

  // Calculate TDEE
  const tdee = calculateTDEE(bmr, userData.activity_level);

  // Round to nearest integer
  return Math.round(tdee);
}

