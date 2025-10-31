import { Pool, PoolClient, QueryResult, QueryResultRow } from 'pg';
import dotenv from 'dotenv';
import fs from 'fs';

// Ensure env is loaded even when this module is imported before app.ts runs dotenv
if (fs.existsSync('.env.local')) {
  dotenv.config({ path: '.env.local' });
} else if (fs.existsSync('ENV.example')) {
  dotenv.config({ path: 'ENV.example' });
}

const connectionString = process.env.DATABASE_URL || 'postgresql://localhost:5432/calcalcal_dev';

// Optimize connection pool for low-memory environments (512MB VPS)
// Default pg pool size is 10, reduce to 5 for better memory usage
const pool = new Pool({
  connectionString,
  max: parseInt(process.env.DB_POOL_MAX || '5', 10), // Default 5, can override with DB_POOL_MAX env var
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

export default class Database {
  static async query<T extends QueryResultRow = QueryResultRow>(text: string, params?: any[]): Promise<QueryResult<T>> {
    return pool.query<T>(text, params);
  }

  static async getClient(): Promise<PoolClient> {
    return pool.connect();
  }
}
