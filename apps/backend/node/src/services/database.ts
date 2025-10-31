import { Pool, PoolClient, QueryResult, QueryResultRow } from 'pg';
import dotenv from 'dotenv';
import fs from 'fs';

// Ensure env is loaded even when this module is imported before app.ts runs dotenv
if (fs.existsSync('.env.local')) {
  dotenv.config({ path: '.env.local' });
} else if (fs.existsSync('ENV.example')) {
  dotenv.config({ path: 'ENV.example' });
}

let connectionString = process.env.DATABASE_URL || 'postgresql://localhost:5432/calcalcal_dev';

// Handle DigitalOcean variable references that weren't resolved
// ${db.connection_string} gets passed as literal string, so we need to handle it
if (connectionString.includes('${') || connectionString.includes('connection_string')) {
  console.error('❌ ERROR: DATABASE_URL contains unresolved variable reference');
  console.error('Current value:', `"${connectionString}"`);
  console.error('');
  console.error('SOLUTION: Set DATABASE_URL manually in DigitalOcean:');
  console.error('1. Go to Components → Database → Connection Details');
  console.error('2. Copy the connection string');
  console.error('3. Go to Settings → Environment Variables');
  console.error('4. Set DATABASE_URL to the actual connection string (not ${db.connection_string})');
  throw new Error('DATABASE_URL contains unresolved variable reference. Please set it manually in DigitalOcean dashboard.');
}

// Validate DATABASE_URL format
if (!connectionString || (!connectionString.startsWith('postgresql://') && !connectionString.startsWith('postgres://'))) {
  console.error('❌ ERROR: DATABASE_URL must start with postgresql:// or postgres://');
  console.error('Current value:', connectionString ? `"${connectionString}"` : 'NOT SET');
  throw new Error('Invalid DATABASE_URL format. Must be a PostgreSQL connection string.');
}

// Log connection string (without password) for debugging
const maskedUrl = connectionString.replace(/:([^:@]+)@/, ':***@');
console.log('Database connection string:', maskedUrl);

// Extract and validate hostname
try {
  const url = new URL(connectionString);
  if (!url.hostname || url.hostname === 'base' || url.hostname.length < 3) {
    console.error('❌ ERROR: Invalid database hostname:', url.hostname);
    console.error('Full connection string (masked):', maskedUrl);
    throw new Error(`Invalid database hostname: ${url.hostname}. Check DATABASE_URL environment variable.`);
  }
} catch (urlError) {
  console.error('❌ ERROR: Failed to parse DATABASE_URL:', urlError);
  console.error('Connection string (masked):', maskedUrl);
  throw new Error('Failed to parse DATABASE_URL. Ensure it is a valid PostgreSQL connection string.');
}

// Parse connection string to extract SSL config
const connectionUrl = new URL(connectionString);
const hasSSL = connectionUrl.searchParams.get('sslmode') === 'require' || 
               connectionUrl.searchParams.get('sslmode') === 'prefer';

// Optimize connection pool for low-memory environments (512MB VPS)
// Default pg pool size is 10, reduce to 5 for better memory usage
const poolConfig: any = {
  connectionString,
  max: parseInt(process.env.DB_POOL_MAX || '5', 10), // Default 5, can override with DB_POOL_MAX env var
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
};

// Configure SSL for DigitalOcean managed databases
if (hasSSL) {
  poolConfig.ssl = {
    rejectUnauthorized: false, // DigitalOcean uses self-signed certs in chain
  };
}

const pool = new Pool(poolConfig);

// Test connection on startup
pool.on('error', (err) => {
  console.error('Unexpected database pool error:', err);
});

pool.query('SELECT NOW()').then(() => {
  console.log('✅ Database connection successful');
}).catch((err) => {
  console.error('❌ Database connection failed:', err.message);
  console.error('Connection string (masked):', connectionString ? connectionString.replace(/:([^:@]+)@/, ':***@') : 'NOT SET');
});

export default class Database {
  static async query<T extends QueryResultRow = QueryResultRow>(text: string, params?: any[]): Promise<QueryResult<T>> {
    return pool.query<T>(text, params);
  }

  static async getClient(): Promise<PoolClient> {
    return pool.connect();
  }
}
