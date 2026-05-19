import Database from '../services/database';
import { calculateCalorieGoal, calculateMacroGoals, UserHealthData } from '../services/calorieCalculator';

export interface User {
  id: string;
  email: string | null;
  name: string | null;
  apple_id: string | null;
  google_id: string | null;
  daily_calorie_goal: number;
  daily_calorie_goal_is_manual: boolean;
  daily_protein_goal: number;
  daily_fat_goal: number;
  daily_carb_goal: number;
  units: string;
  timezone_offset: number;
  // Health and profile fields (all optional)
  weight_kg?: number | null;
  height_cm?: number | null;
  age?: number | null;
  activity_level?: 'sedentary' | 'light' | 'moderate' | 'active' | 'very_active' | 'small' | null;
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
  private static readonly updateableFields = new Set([
    'email',
    'name',
    'daily_calorie_goal',
    'daily_calorie_goal_is_manual',
    'daily_protein_goal',
    'daily_fat_goal',
    'daily_carb_goal',
    'units',
    'timezone_offset',
    'weight_kg',
    'height_cm',
    'age',
    'activity_level',
    'target_weight_kg',
    'gender',
    'weight_unit',
    'height_unit',
    'onboarding_completed',
  ]);

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
      'target_weight_kg',
    ];

    // Check if any health fields are being updated
    const hasHealthFieldUpdate = healthFields.some((field) => field in updates);

    const hasCalorieGoalUpdate = 'daily_calorie_goal' in updates;
    const hasCalorieGoalManualFlagUpdate = 'daily_calorie_goal_is_manual' in updates;
    const isResettingToCalculatedGoal =
      hasCalorieGoalManualFlagUpdate && updates.daily_calorie_goal_is_manual === false;

    // A caller that submits a calorie value without an explicit source is choosing
    // a custom value. Onboarding and reset flows should send the flag explicitly.
    if (hasCalorieGoalUpdate && !hasCalorieGoalManualFlagUpdate) {
      updates.daily_calorie_goal_is_manual = true;
    }

    const calorieGoalIsManual =
      updates.daily_calorie_goal_is_manual !== undefined
        ? updates.daily_calorie_goal_is_manual === true
        : existing.daily_calorie_goal_is_manual === true;

    // Check if any macro is explicitly provided (manual override)
    const hasManualProtein = 'daily_protein_goal' in updates;
    const hasManualFat = 'daily_fat_goal' in updates;
    const hasManualCarb = 'daily_carb_goal' in updates;
    const hasAnyManualMacro = hasManualProtein || hasManualFat || hasManualCarb;

    // Build merged health data once — reused for calorie and macro calc
    const mergedHealth: UserHealthData = {
      weight_kg: updates.weight_kg !== undefined ? updates.weight_kg : existing.weight_kg,
      height_cm: updates.height_cm !== undefined ? updates.height_cm : existing.height_cm,
      age: updates.age !== undefined ? updates.age : existing.age ?? undefined,
      activity_level: updates.activity_level !== undefined
        ? updates.activity_level
        : existing.activity_level ?? undefined,
      gender: updates.gender !== undefined ? updates.gender : existing.gender ?? undefined,
      weight_unit: updates.weight_unit || existing.weight_unit || 'kg',
      height_unit: updates.height_unit || existing.height_unit || 'cm',
      target_weight_kg: updates.target_weight_kg !== undefined
        ? updates.target_weight_kg
        : existing.target_weight_kg ?? undefined,
    };

    // Auto-calculate calorie goal when health fields change unless the user has
    // locked in a manual goal. Also recalculate when explicitly resetting to
    // calculated mode without sending a calorie value.
    if (
      ((hasHealthFieldUpdate && !hasCalorieGoalUpdate) ||
        (isResettingToCalculatedGoal && !hasCalorieGoalUpdate)) &&
      !calorieGoalIsManual
    ) {
      const calculatedGoal = calculateCalorieGoal(mergedHealth);
      updates.daily_calorie_goal = calculatedGoal;
    }

    // Auto-calculate macro goals whenever:
    //  - any health field changes, OR
    //  - calorie goal was updated or reset
    // ...unless the caller is explicitly setting a macro themselves (per-field override).
    // Macros are calculated against the *final* calorie goal landing in this update.
    const shouldRecalcMacros =
      (hasHealthFieldUpdate || hasCalorieGoalUpdate || isResettingToCalculatedGoal) &&
      !hasAnyManualMacro;

    if (shouldRecalcMacros) {
      const finalCalorieGoal =
        updates.daily_calorie_goal !== undefined
          ? updates.daily_calorie_goal
          : existing.daily_calorie_goal;
      const macros = calculateMacroGoals(mergedHealth, finalCalorieGoal);
      updates.daily_protein_goal = macros.daily_protein_goal;
      updates.daily_fat_goal = macros.daily_fat_goal;
      updates.daily_carb_goal = macros.daily_carb_goal;
    }

    const keys = Object.keys(updates).filter((k) => k !== 'id');
    const unsupportedKeys = keys.filter((key) => !this.updateableFields.has(key));
    if (unsupportedKeys.length > 0) {
      throw new Error(`Unsupported user update field(s): ${unsupportedKeys.join(', ')}`);
    }

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

  /**
   * Delete a user account and all associated data
   * This operation is performed in a transaction to ensure data integrity
   * @param userId User ID to delete
   * @returns True if deletion successful
   */
  static async deleteAccount(userId: string): Promise<boolean> {
    const client = await Database.getClient();
    try {
      await client.query('BEGIN');

      // Get all user's diary entries to collect images before deletion
      const entriesResult = await client.query(
        'SELECT images FROM diary_entries WHERE user_id = $1',
        [userId]
      );
      
      // Collect all unique image URLs/object keys
      const allImages: string[] = [];
      for (const row of entriesResult.rows) {
        if (row.images && Array.isArray(row.images)) {
          allImages.push(...row.images);
        }
      }
      
      // Delete user's diary entries first (due to foreign key constraints)
      await client.query('DELETE FROM diary_entries WHERE user_id = $1', [userId]);

      // Delete user's popular food items
      await client.query('DELETE FROM popular_food_items WHERE user_id = $1', [userId]);

      // Delete user's refresh tokens
      await client.query('DELETE FROM refresh_tokens WHERE user_id = $1', [userId]);

      // Finally delete the user profile
      const result = await client.query('DELETE FROM user_profiles WHERE id = $1', [userId]);

      await client.query('COMMIT');

      // Delete user's images from Cloudflare R2 after successful database deletion
      if (allImages.length > 0) {
        try {
          const { deleteAllUserImages } = await import('../services/storage/r2');
          const deletedCount = await deleteAllUserImages(userId);
          console.log(`✅ Deleted ${deletedCount} images from R2 for user ${userId}`);
        } catch (imageError) {
          console.error(`⚠️ Failed to delete images from R2 for user ${userId}:`, imageError);
          // Don't fail the account deletion, but log the error for manual cleanup
        }
      }

      return (result.rowCount ?? 0) > 0;
    } catch (error) {
      await client.query('ROLLBACK');
      console.error('Failed to delete user account:', error);
      throw error;
    } finally {
      client.release();
    }
  }
}
