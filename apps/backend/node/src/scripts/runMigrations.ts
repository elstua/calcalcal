import { spawnSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';

// Load env from .env.local or ENV.example
if (fs.existsSync(path.resolve(process.cwd(), '.env.local'))) {
  dotenv.config({ path: path.resolve(process.cwd(), '.env.local') });
} else if (fs.existsSync(path.resolve(process.cwd(), 'ENV.example'))) {
  dotenv.config({ path: path.resolve(process.cwd(), 'ENV.example') });
}

const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) {
  console.error('ERROR: DATABASE_URL is not set. Please set it in .env.local or ENV.example.');
  process.exit(1);
}

const migrationsDir = path.resolve(process.cwd(), 'migrations');
if (!fs.existsSync(migrationsDir)) {
  console.error(`ERROR: Migrations directory not found at ${migrationsDir}`);
  process.exit(1);
}

// Collect *.sql files sorted by name
const migrationFiles = fs
  .readdirSync(migrationsDir)
  .filter((f) => f.endsWith('.sql'))
  .sort();

if (migrationFiles.length === 0) {
  console.log('No migration files found.');
  process.exit(0);
}

console.log(`Running ${migrationFiles.length} migration(s) using DATABASE_URL`);

for (const file of migrationFiles) {
  const filePath = path.join(migrationsDir, file);
  console.log(`\nApplying migration: ${file}`);
  const result = spawnSync('psql', [DATABASE_URL, '-f', filePath], {
    stdio: 'inherit',
    env: process.env,
  });
  if (result.status !== 0) {
    console.error(`Migration failed: ${file}`);
    process.exit(result.status ?? 1);
  }
}

console.log('\nAll migrations applied successfully.');











