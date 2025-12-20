import Database from '../services/database';
import { calculateCalorieGoal, UserHealthData } from '../services/calorieCalculator';

export interface User {
  id: string;
  email: string | null;
  name: string | null;
  apple_id: string | null;
  google_id: string | null;
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
  onboarding_completed?: boolean | null;
  // Temporary account fields
  is_temporary?: boolean;
  device_id?: string | null;
  created_via?: 'apple' | 'google' | 'temporary' | null;
  created_at: string;
  updated_at: string;
}

export class UserModel {
  static async findByAppleId(appleId: string): Promise<User | null> {
    const result = await Database.query<User>(
      'SELECT * FROM user_profiles WHERE apple_id = $1',
      [appleId]
    );
    return result.rows[0] || null;
  }

  static async findByGoogleId(googleId: string): Promise<User | null> {
    const result = await Database.query<User>(
      'SELECT * FROM user_profiles WHERE google_id = $1',
      [googleId]
    );
    return result.rows[0] || null;
  }

  static async findById(id: string): Promise<User | null> {
    const result = await Database.query<User>(
      'SELECT * FROM user_profiles WHERE id = $1',
      [id]
    );
    return result.rows[0] || null;
  }

  static async findByDeviceId(deviceId: string): Promise<User | null> {
    const result = await Database.query<User>(
      'SELECT * FROM user_profiles WHERE device_id = $1',
      [deviceId]
    );
    return result.rows[0] || null;
  }

  /**
   * Create a temporary user account (no OAuth required)
   * @param deviceId Unique device identifier
   * @returns Created temporary user
   */
  static async createTemporaryUser(deviceId: string): Promise<User> {
    const { v4: uuidv4 } = await import('uuid');
    const userId = uuidv4();
    
    const result = await Database.query<User>(
      `INSERT INTO user_profiles (id, device_id, is_temporary, created_via, updated_at)
       VALUES ($1, $2, TRUE, 'temporary', NOW())
       RETURNING *`,
      [userId, deviceId]
    );
    return result.rows[0];
  }

  /**
   * Upgrade a temporary account to a permanent account with OAuth
   * Links the OAuth provider to the existing temporary account
   * @param userId The temporary user's ID
   * @param appleId Apple ID (optional)
   * @param googleId Google ID (optional)
   * @param email User's email (optional)
   * @param name User's name (optional)
   * @returns Updated user
   */
  static async upgradeTemporaryAccount(
    userId: string,
    appleId: string | null,
    googleId: string | null,
    email?: string,
    name?: string
  ): Promise<User> {
    // Determine created_via based on which OAuth provider is being used
    const createdVia = appleId ? 'apple' : googleId ? 'google' : 'temporary';
    
    const result = await Database.query<User>(
      `UPDATE user_profiles 
       SET is_temporary = FALSE,
           apple_id = COALESCE($2, apple_id),
           google_id = COALESCE($3, google_id),
           email = COALESCE($4, email),
           name = COALESCE($5, name),
           created_via = $6,
           updated_at = NOW()
       WHERE id = $1
       RETURNING *`,
      [userId, appleId, googleId, email ?? null, name ?? null, createdVia]
    );
    
    if (result.rows.length === 0) {
      throw new Error('User not found');
    }
    
    return result.rows[0];
  }

  static async upsertUser(
    id: string,
    appleId: string | null,
    email?: string,
    name?: string,
    googleId?: string | null
  ): Promise<User> {
    const result = await Database.query<User>(
      `INSERT INTO user_profiles (id, apple_id, google_id, email, name, updated_at)
       VALUES ($1, $2, $3, $4, $5, NOW())
       ON CONFLICT (id) DO UPDATE 
       SET email = COALESCE(EXCLUDED.email, user_profiles.email),
           name = COALESCE(EXCLUDED.name, user_profiles.name),
           apple_id = COALESCE(EXCLUDED.apple_id, user_profiles.apple_id),
           google_id = COALESCE(EXCLUDED.google_id, user_profiles.google_id),
           updated_at = NOW()
       RETURNING *`,
      [id, appleId, googleId ?? null, email ?? null, name ?? null]
    );
    return result.rows[0];
  }

  static async update(id: string, updates: Partial<User>): Promise<User> {
    // Get existing user data for auto-calculation
    const existing = await this.findById(id);
    if (!existing) throw new Error('User not found');

    // Fields that trigger calorie recalculation
    const healthFields = [
      'weight_kg',
      'height_cm',
      'age',
      'activity_level',
      'gender',
      'weight_unit',
      'height_unit',
    ];

    // Check if any health fields are being updated
    const hasHealthFieldUpdate = healthFields.some((field) => field in updates);

    // Check if daily_calorie_goal is explicitly provided (manual override)
    const hasManualCalorieGoal = 'daily_calorie_goal' in updates;

    // Auto-calculate calorie goal if health fields are updated and no manual override
    if (hasHealthFieldUpdate && !hasManualCalorieGoal) {
      // Merge existing data with updates for calculation
      const healthData: UserHealthData = {
        weight_kg: updates.weight_kg !== undefined ? updates.weight_kg : existing.weight_kg,
        height_cm: updates.height_cm !== undefined ? updates.height_cm : existing.height_cm,
        age: updates.age !== undefined ? updates.age : existing.age ?? undefined,
        activity_level: updates.activity_level !== undefined
          ? updates.activity_level
          : existing.activity_level ?? undefined,
        gender: updates.gender !== undefined ? updates.gender : existing.gender ?? undefined,
        weight_unit: updates.weight_unit || existing.weight_unit || 'kg',
        height_unit: updates.height_unit || existing.height_unit || 'cm',
      };

      const calculatedGoal = calculateCalorieGoal(healthData);
      updates.daily_calorie_goal = calculatedGoal;
    }

    const keys = Object.keys(updates).filter((k) => k !== 'id');
    if (keys.length === 0) {
      return existing;
    }
    const values = keys.map((k) => (updates as any)[k]);
    const setClause = keys.map((k, i) => `${k} = $${i + 2}`).join(', ');

    const result = await Database.query<User>(
      `UPDATE user_profiles SET ${setClause}, updated_at = NOW()
       WHERE id = $1 RETURNING *`,
      [id, ...values]
    );
    return result.rows[0];
  }
}


