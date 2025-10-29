import Database from '../services/database';

export interface User {
  id: string;
  email: string | null;
  name: string | null;
  apple_id: string | null;
  daily_calorie_goal: number;
  daily_protein_goal: number;
  daily_fat_goal: number;
  daily_carb_goal: number;
  units: string;
  timezone_offset: number;
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

  static async findById(id: string): Promise<User | null> {
    const result = await Database.query<User>(
      'SELECT * FROM user_profiles WHERE id = $1',
      [id]
    );
    return result.rows[0] || null;
  }

  static async upsertUser(
    id: string,
    appleId: string | null,
    email?: string,
    name?: string
  ): Promise<User> {
    const result = await Database.query<User>(
      `INSERT INTO user_profiles (id, apple_id, email, name, updated_at)
       VALUES ($1, $2, $3, $4, NOW())
       ON CONFLICT (id) DO UPDATE 
       SET email = COALESCE(EXCLUDED.email, user_profiles.email),
           name = COALESCE(EXCLUDED.name, user_profiles.name),
           updated_at = NOW()
       RETURNING *`,
      [id, appleId, email ?? null, name ?? null]
    );
    return result.rows[0];
  }

  static async update(id: string, updates: Partial<User>): Promise<User> {
    const keys = Object.keys(updates).filter((k) => k !== 'id');
    if (keys.length === 0) {
      const existing = await this.findById(id);
      if (!existing) throw new Error('User not found');
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


