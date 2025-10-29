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

const pool = new Pool({ connectionString });

export default class Database {
  static async query<T extends QueryResultRow = QueryResultRow>(text: string, params?: any[]): Promise<QueryResult<T>> {
    return pool.query<T>(text, params);
  }

  static async getClient(): Promise<PoolClient> {
    return pool.connect();
  }
}
