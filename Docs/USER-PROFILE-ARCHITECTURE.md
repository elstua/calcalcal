# User Profile Architecture Documentation

## Overview

The CalCalCal backend manages comprehensive user profile information including authentication data, health metrics, and nutrition goals. The system automatically calculates daily calorie goals based on user health data using the Mifflin-St Jeor equation, while allowing manual overrides when needed.

## Table of Contents

1. [Database Schema](#database-schema)
2. [Data Model](#data-model)
3. [API Endpoints](#api-endpoints)
4. [Calorie Calculation](#calorie-calculation)
5. [Auto-Calculation Logic](#auto-calculation-logic)
6. [Field Descriptions](#field-descriptions)
7. [Usage Examples](#usage-examples)
8. [Error Handling](#error-handling)

---

## Database Schema

### Table: `user_profiles`

The `user_profiles` table stores all user information including authentication, health metrics, and nutrition goals.

#### Core Fields

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | uuid | NO | - | Primary key, unique user identifier |
| `email` | text | YES | NULL | User's email address |
| `name` | text | YES | NULL | User's display name |
| `apple_id` | text | YES | NULL | Apple Sign-In identifier (unique) |
| `created_at` | timestamptz | YES | now() | Account creation timestamp |
| `updated_at` | timestamptz | YES | now() | Last update timestamp |

#### Nutrition Goals

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `daily_calorie_goal` | integer | YES | 2000 | Daily calorie target (kcal) |
| `daily_protein_goal` | numeric | YES | 50.0 | Daily protein target (grams) |
| `daily_fat_goal` | numeric | YES | 65.0 | Daily fat target (grams) |
| `daily_carb_goal` | numeric | YES | 250.0 | Daily carbohydrate target (grams) |
| `units` | text | YES | 'kcal' | Energy unit preference ('kcal' or 'kJ') |
| `timezone_offset` | integer | YES | 0 | User's timezone offset (minutes) |

#### Health & Profile Fields (Optional)

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `weight_kg` | numeric | YES | NULL | Current weight in kilograms |
| `height_cm` | numeric | YES | NULL | Height in centimeters |
| `age` | integer | YES | NULL | User's age in years |
| `activity_level` | text | YES | NULL | Activity level: 'small', 'moderate', 'active' |
| `target_weight_kg` | numeric | YES | NULL | Goal/target weight in kilograms |
| `gender` | text | YES | NULL | Gender: 'male', 'female', 'other' |
| `weight_unit` | text | YES | 'kg' | Preferred weight unit: 'kg' or 'lbs' |
| `height_unit` | text | YES | 'cm' | Preferred height unit: 'cm' or 'in' |

#### Constraints

**CHECK Constraints:**
- `user_profiles_activity_level_check`: `activity_level` must be NULL or one of: 'small', 'moderate', 'active'
- `user_profiles_gender_check`: `gender` must be NULL or one of: 'male', 'female', 'other'
- `user_profiles_weight_unit_check`: `weight_unit` must be 'kg' or 'lbs'
- `user_profiles_height_unit_check`: `height_unit` must be 'cm' or 'in'
- `user_profiles_units_check`: `units` must be 'kcal' or 'kJ'

**Unique Constraints:**
- `user_profiles_pkey`: Primary key on `id`
- `user_profiles_apple_id_key`: Unique constraint on `apple_id`

---

## Data Model

### TypeScript Interface: `User`

```typescript
export interface User {
  // Core fields
  id: string;
  email: string | null;
  name: string | null;
  apple_id: string | null;
  
  // Nutrition goals
  daily_calorie_goal: number;
  daily_protein_goal: number;
  daily_fat_goal: number;
  daily_carb_goal: number;
  units: string;
  timezone_offset: number;
  
  // Health and profile fields (all optional)
  weight_kg?: number | null;
  height_cm?: number | null;
  age?: number | null;
  activity_level?: 'small' | 'moderate' | 'active' | null;
  target_weight_kg?: number | null;
  gender?: 'male' | 'female' | 'other' | null;
  weight_unit?: 'kg' | 'lbs';
  height_unit?: 'cm' | 'in';
  
  // Timestamps
  created_at: string;
  updated_at: string;
}
```

### Health Data Interface: `UserHealthData`

Used for calorie calculation:

```typescript
export interface UserHealthData {
  weight_kg?: number | null;
  height_cm?: number | null;
  age?: number | null;
  activity_level?: 'small' | 'moderate' | 'active' | null;
  gender?: 'male' | 'female' | 'other' | null;
  weight_unit?: 'kg' | 'lbs';
  height_unit?: 'cm' | 'in';
}
```

---

## API Endpoints

### GET /api/auth/profile

Retrieves the current user's profile information.

**Authentication:** Required (Bearer token)

**Request:**
```http
GET /api/auth/profile
Authorization: Bearer {access_token}
```

**Response (200 OK):**
```json
{
  "success": true,
  "profile": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "John Doe",
    "apple_id": "apple_user_id",
    "daily_calorie_goal": 2400,
    "daily_protein_goal": 50.0,
    "daily_fat_goal": 65.0,
    "daily_carb_goal": 250.0,
    "units": "kcal",
    "timezone_offset": 0,
    "weight_kg": 70,
    "height_cm": 175,
    "age": 30,
    "activity_level": "moderate",
    "target_weight_kg": 65,
    "gender": "male",
    "weight_unit": "kg",
    "height_unit": "cm",
    "created_at": "2025-01-15T10:00:00Z",
    "updated_at": "2025-01-15T10:00:00Z"
  }
}
```

**Error Responses:**
- `401 Unauthorized`: Missing or invalid authentication token
- `404 Not Found`: User not found
- `500 Internal Server Error`: Server error

---

### PUT /api/auth/profile

Updates user profile information. Supports partial updates - only provided fields are updated.

**Authentication:** Required (Bearer token)

**Request:**
```http
PUT /api/auth/profile
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "weight_kg": 70,
  "height_cm": 175,
  "age": 30,
  "activity_level": "moderate",
  "gender": "male",
  "target_weight_kg": 65,
  "weight_unit": "kg",
  "height_unit": "cm",
  "daily_calorie_goal": 2400  // Optional: manual override
}
```

**Request Body Fields (all optional):**

| Field | Type | Description |
|-------|------|-------------|
| `weight_kg` | number | Current weight in kilograms (or lbs if `weight_unit` is 'lbs') |
| `height_cm` | number | Height in centimeters (or inches if `height_unit` is 'in') |
| `age` | number | Age in years |
| `activity_level` | string | Activity level: 'small', 'moderate', 'active' |
| `gender` | string \| null | Gender: 'male', 'female', 'other', or null |
| `target_weight_kg` | number | Goal/target weight in kilograms |
| `weight_unit` | string | Preferred weight unit: 'kg' or 'lbs' |
| `height_unit` | string | Preferred height unit: 'cm' or 'in' |
| `daily_calorie_goal` | number | Manual calorie goal override (prevents auto-calculation) |
| `daily_protein_goal` | number | Daily protein goal in grams |
| `daily_fat_goal` | number | Daily fat goal in grams |
| `daily_carb_goal` | number | Daily carbohydrate goal in grams |
| `email` | string | Email address |
| `name` | string | Display name |

**Response (200 OK):**
```json
{
  "success": true,
  "profile": {
    // Updated user profile object
  }
}
```

**Error Responses:**
- `400 Bad Request`: Invalid field values (enum validation, negative numbers, etc.)
- `401 Unauthorized`: Missing or invalid authentication token
- `500 Internal Server Error`: Server error

**Validation Rules:**
- `activity_level` must be one of: 'small', 'moderate', 'active'
- `gender` must be one of: 'male', 'female', 'other', or null
- `weight_unit` must be 'kg' or 'lbs'
- `height_unit` must be 'cm' or 'in'
- Numeric fields (`weight_kg`, `height_cm`, `age`, `target_weight_kg`, `daily_calorie_goal`) must be non-negative numbers

---

## Calorie Calculation

### Overview

The system automatically calculates daily calorie goals using the **Mifflin-St Jeor equation** for Basal Metabolic Rate (BMR) combined with activity level multipliers for Total Daily Energy Expenditure (TDEE).

### Calculation Formula

#### Step 1: Calculate BMR (Basal Metabolic Rate)

**For Men:**
```
BMR = (10 × weight_kg) + (6.25 × height_cm) - (5 × age) + 5
```

**For Women:**
```
BMR = (10 × weight_kg) + (6.25 × height_cm) - (5 × age) - 161
```

**For Other/Unknown:**
```
BMR = Average of male and female formulas
```

#### Step 2: Calculate TDEE (Total Daily Energy Expenditure)

```
TDEE = BMR × Activity Multiplier
```

**Activity Multipliers:**
- `small`: 1.2 (Sedentary - little or no exercise)
- `moderate`: 1.55 (Moderately active - exercise 3-5 days/week)
- `active`: 1.725 (Very active - exercise 6-7 days/week)

#### Step 3: Round to Nearest Integer

The final `daily_calorie_goal` is rounded to the nearest whole number.

### Default Behavior

If insufficient data is provided for calculation (missing `weight_kg`, `height_cm`, `age`, or `activity_level`), the system defaults to **2000 kcal**.

### Unit Conversion

The system stores data in metric units internally but accepts both metric and imperial:

- **Weight**: Converts lbs → kg for calculation (1 lb = 0.453592 kg)
- **Height**: Converts inches → cm for calculation (1 inch = 2.54 cm)

The original values and units are preserved in the database.

### Example Calculation

**Input:**
- Weight: 80 kg
- Height: 180 cm
- Age: 35 years
- Gender: male
- Activity: moderate

**Calculation:**
1. BMR = (10 × 80) + (6.25 × 180) - (5 × 35) + 5 = 1755 kcal
2. TDEE = 1755 × 1.55 = 2720.25 kcal
3. Rounded = **2720 kcal**

---

## Auto-Calculation Logic

### When Auto-Calculation Triggers

The `daily_calorie_goal` is automatically recalculated when any of these health fields are updated:

- `weight_kg`
- `height_cm`
- `age`
- `activity_level`
- `gender`
- `weight_unit` (affects weight conversion)
- `height_unit` (affects height conversion)

### When Auto-Calculation is Skipped

Auto-calculation is **not** performed if:

1. **Manual Override**: `daily_calorie_goal` is explicitly provided in the update request
2. **Insufficient Data**: Required fields (`weight_kg`, `height_cm`, `age`, `activity_level`) are missing
3. **No Health Field Changes**: Update doesn't include any health-related fields

### Calculation Process

1. **Merge Data**: Combine existing user data with new updates
2. **Unit Conversion**: Convert imperial units to metric if needed
3. **Validate Data**: Check for valid ranges and required fields
4. **Calculate**: Use Mifflin-St Jeor equation + activity multiplier
5. **Update**: Set `daily_calorie_goal` with calculated value
6. **Preserve Override**: If `daily_calorie_goal` was explicitly set, use that instead

### Example Scenarios

#### Scenario 1: Auto-Calculation on Health Update
```json
PUT /api/auth/profile
{
  "weight_kg": 70,
  "height_cm": 175,
  "age": 30,
  "activity_level": "moderate",
  "gender": "male"
}
```
**Result:** `daily_calorie_goal` is automatically calculated (~2400-2500 kcal)

#### Scenario 2: Manual Override Preserved
```json
PUT /api/auth/profile
{
  "daily_calorie_goal": 1800,
  "weight_kg": 65
}
```
**Result:** `daily_calorie_goal` remains 1800 (not recalculated)

#### Scenario 3: Partial Update Triggers Recalculation
```json
PUT /api/auth/profile
{
  "activity_level": "active"
}
```
**Result:** `daily_calorie_goal` is recalculated with new activity level (if other required fields exist)

---

## Field Descriptions

### Core Fields

#### `id` (uuid, required)
Unique identifier for the user. Generated during account creation.

#### `email` (text, nullable)
User's email address. Can be null if not provided during sign-up.

#### `name` (text, nullable)
User's display name. Can be null if not provided.

#### `apple_id` (text, nullable, unique)
Apple Sign-In identifier. Used for authentication. Must be unique.

### Nutrition Goals

#### `daily_calorie_goal` (integer, default: 2000)
Daily calorie target in kilocalories (kcal). Automatically calculated from health data, but can be manually overridden.

#### `daily_protein_goal` (numeric, default: 50.0)
Daily protein target in grams.

#### `daily_fat_goal` (numeric, default: 65.0)
Daily fat target in grams.

#### `daily_carb_goal` (numeric, default: 250.0)
Daily carbohydrate target in grams.

#### `units` (text, default: 'kcal')
Energy unit preference. Must be 'kcal' or 'kJ'.

#### `timezone_offset` (integer, default: 0)
User's timezone offset in minutes from UTC.

### Health Fields

#### `weight_kg` (numeric, nullable)
Current weight. Stored in kilograms, but can be provided in pounds if `weight_unit` is 'lbs'. Used for calorie calculation.

#### `height_cm` (numeric, nullable)
Height. Stored in centimeters, but can be provided in inches if `height_unit` is 'in'. Used for calorie calculation.

#### `age` (integer, nullable)
User's age in years. Required for accurate calorie calculation.

#### `activity_level` (text, nullable)
Activity level classification:
- `'small'`: Sedentary lifestyle (multiplier: 1.2)
- `'moderate'`: Moderately active, exercise 3-5 days/week (multiplier: 1.55)
- `'active'`: Very active, exercise 6-7 days/week (multiplier: 1.725)

Required for calorie calculation.

#### `target_weight_kg` (numeric, nullable)
Goal or target weight in kilograms. Separate from current weight, useful for tracking weight loss/gain goals.

#### `gender` (text, nullable)
Gender identifier:
- `'male'`: Uses male BMR formula (+5 constant)
- `'female'`: Uses female BMR formula (-161 constant)
- `'other'`: Uses average of male/female formulas
- `null`: Uses average of male/female formulas

#### `weight_unit` (text, default: 'kg')
Preferred weight unit for display/input:
- `'kg'`: Kilograms
- `'lbs'`: Pounds

Affects unit conversion for calorie calculation.

#### `height_unit` (text, default: 'cm')
Preferred height unit for display/input:
- `'cm'`: Centimeters
- `'in'`: Inches

Affects unit conversion for calorie calculation.

---

## Usage Examples

### Example 1: Complete Profile Setup

```bash
curl -X PUT http://localhost:3000/api/auth/profile \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "weight_kg": 70,
    "height_cm": 175,
    "age": 30,
    "activity_level": "moderate",
    "gender": "male",
    "target_weight_kg": 65,
    "weight_unit": "kg",
    "height_unit": "cm"
  }'
```

**Result:** Profile updated with all health data, `daily_calorie_goal` automatically calculated.

### Example 2: Using Imperial Units

```bash
curl -X PUT http://localhost:3000/api/auth/profile \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "weight_kg": 154,
    "height_cm": 69,
    "age": 25,
    "activity_level": "active",
    "gender": "female",
    "weight_unit": "lbs",
    "height_unit": "in"
  }'
```

**Result:** Values converted internally for calculation, original units preserved.

### Example 3: Partial Update

```bash
curl -X PUT http://localhost:3000/api/auth/profile \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "activity_level": "active"
  }'
```

**Result:** Only activity level updated, calorie goal recalculated if other required fields exist.

### Example 4: Manual Calorie Override

```bash
curl -X PUT http://localhost:3000/api/auth/profile \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "daily_calorie_goal": 1800,
    "weight_kg": 65
  }'
```

**Result:** Calorie goal set to 1800 (manual override), weight updated, no recalculation.

### Example 5: Get Profile

```bash
curl -X GET http://localhost:3000/api/auth/profile \
  -H "Authorization: Bearer {token}"
```

**Result:** Returns complete user profile with all fields.

---

## Error Handling

### Validation Errors (400 Bad Request)

**Invalid Activity Level:**
```json
{
  "error": "Invalid activity_level",
  "message": "activity_level must be one of: small, moderate, active"
}
```

**Invalid Gender:**
```json
{
  "error": "Invalid gender",
  "message": "gender must be one of: male, female, other, or null"
}
```

**Invalid Unit:**
```json
{
  "error": "Invalid weight_unit",
  "message": "weight_unit must be one of: kg, lbs"
}
```

**Negative Number:**
```json
{
  "error": "Invalid weight_kg",
  "message": "weight_kg must be a non-negative number"
}
```

### Authentication Errors (401 Unauthorized)

**Missing Token:**
```json
{
  "error": "Missing authorization header"
}
```

**Invalid Token:**
```json
{
  "error": "Invalid token"
}
```

### Not Found (404 Not Found)

**User Not Found:**
```json
{
  "error": "User not found"
}
```

### Server Errors (500 Internal Server Error)

**Generic Error:**
```json
{
  "error": "Failed to update profile",
  "message": "Error details"
}
```

---

## Implementation Details

### File Structure

```
apps/backend/node/src/
├── models/
│   └── User.ts                    # User model and interface
├── routes/
│   └── auth.ts                    # Profile endpoints
└── services/
    └── calorieCalculator.ts       # Calorie calculation logic
```

### Key Components

1. **UserModel** (`models/User.ts`): Handles database operations and auto-calculation logic
2. **CalorieCalculator** (`services/calorieCalculator.ts`): Contains BMR/TDEE calculation functions
3. **Auth Routes** (`routes/auth.ts`): API endpoint handlers with validation

### Database Migration

Migration file: `apps/backend/node/migrations/003_add_user_health_fields.sql`

Run migrations:
```bash
cd apps/backend/node
npm run migrate
```

---

## Best Practices

1. **Always validate input** on the client side before sending to API
2. **Use partial updates** - only send fields that need to change
3. **Respect manual overrides** - if user sets calorie goal manually, don't auto-recalculate
4. **Handle unit conversions** - let users input in their preferred units
5. **Provide defaults** - system gracefully handles missing data with sensible defaults
6. **Update timestamps** - `updated_at` is automatically maintained

---

## Future Enhancements

Potential additions to the user profile system:

- Body fat percentage
- Fitness goals (weight loss, muscle gain, maintenance)
- Dietary preferences/restrictions
- Meal timing preferences
- Custom macro ratios
- Historical weight tracking
- Activity tracking integration

---

**Last Updated:** January 2025
**Version:** 1.0

