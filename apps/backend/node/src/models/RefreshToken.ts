import crypto from 'crypto';
import Database from '../services/database';

export interface RefreshTokenRecord {
  id: string;
  user_id: string;
  token_hash: string;
  created_at: string;
  revoked_at: string | null;
  expires_at: string;
  user_agent: string | null;
  ip_address: string | null;
}

export class RefreshTokenModel {
  static hash(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  static async create(
    userId: string,
    rawToken: string,
    expiresAt: Date,
    opts?: { userAgent?: string; ipAddress?: string }
  ): Promise<RefreshTokenRecord> {
    const tokenHash = this.hash(rawToken);
    const result = await Database.query<RefreshTokenRecord>(
      `INSERT INTO refresh_tokens (user_id, token_hash, expires_at, user_agent, ip_address)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [userId, tokenHash, expiresAt.toISOString(), opts?.userAgent ?? null, opts?.ipAddress ?? null]
    );
    return result.rows[0];
  }

  static async findActiveByHash(tokenHash: string): Promise<RefreshTokenRecord | null> {
    const result = await Database.query<RefreshTokenRecord>(
      `SELECT * FROM refresh_tokens
       WHERE token_hash = $1 AND revoked_at IS NULL AND expires_at > NOW()`,
      [tokenHash]
    );
    return result.rows[0] ?? null;
  }

  static async revokeById(id: string): Promise<void> {
    await Database.query(
      `UPDATE refresh_tokens SET revoked_at = NOW() WHERE id = $1 AND revoked_at IS NULL`,
      [id]
    );
  }

  static async revokeAllForUser(userId: string): Promise<void> {
    await Database.query(
      `UPDATE refresh_tokens SET revoked_at = NOW() WHERE user_id = $1 AND revoked_at IS NULL`,
      [userId]
    );
  }
}



