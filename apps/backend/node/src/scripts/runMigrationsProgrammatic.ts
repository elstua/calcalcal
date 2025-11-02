import Database from '../services/database';
import fs from 'fs';
import path from 'path';

const migrationsDir = path.resolve(process.cwd(), 'migrations');
if (!fs.existsSync(migrationsDir)) {
  console.error(`ERROR: Migrations directory not found at ${migrationsDir}`);
  process.exit(1);
}

// Create migrations tracking table if it doesn't exist
async function ensureMigrationsTable() {
  await Database.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id SERIAL PRIMARY KEY,
      filename TEXT NOT NULL UNIQUE,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
}

// Check if a migration has already been applied
async function isMigrationApplied(filename: string): Promise<boolean> {
  const result = await Database.query(
    'SELECT 1 FROM schema_migrations WHERE filename = $1',
    [filename]
  );
  return result.rows.length > 0;
}

// Mark a migration as applied
async function markMigrationApplied(filename: string) {
  await Database.query(
    'INSERT INTO schema_migrations (filename) VALUES ($1)',
    [filename]
  );
}

// Run a single migration file
async function runMigration(filePath: string, filename: string) {
  console.log(`\nApplying migration: ${filename}`);
  
  const sql = fs.readFileSync(filePath, 'utf-8');
  
  // Execute the migration SQL (migration files may contain their own BEGIN/COMMIT)
  // We wrap marking as applied in a separate transaction to ensure it's recorded
  const client = await Database.getClient();
  try {
    // Execute the migration SQL
    await client.query(sql);
    
    // Mark as applied in a separate transaction
    await markMigrationApplied(filename);
    
    console.log(`✅ Migration applied: ${filename}`);
  } catch (error: any) {
    console.error(`❌ Migration failed: ${filename}`);
    console.error('Error:', error.message);
    throw error;
  } finally {
    client.release();
  }
}

// Main migration runner
async function runMigrations() {
  try {
    // Ensure migrations table exists
    await ensureMigrationsTable();
    
    // Collect *.sql files sorted by name
    const migrationFiles = fs
      .readdirSync(migrationsDir)
      .filter((f) => f.endsWith('.sql'))
      .sort();
    
    if (migrationFiles.length === 0) {
      console.log('No migration files found.');
      return;
    }
    
    console.log(`Found ${migrationFiles.length} migration file(s)`);
    
    // Check which migrations need to be run
    const migrationsToRun: string[] = [];
    for (const file of migrationFiles) {
      const isApplied = await isMigrationApplied(file);
      if (!isApplied) {
        migrationsToRun.push(file);
      } else {
        console.log(`⏭️  Skipping already applied migration: ${file}`);
      }
    }
    
    if (migrationsToRun.length === 0) {
      console.log('\n✅ All migrations are already applied.');
      return;
    }
    
    console.log(`\nRunning ${migrationsToRun.length} new migration(s)...`);
    
    // Run migrations in order
    for (const file of migrationsToRun) {
      const filePath = path.join(migrationsDir, file);
      await runMigration(filePath, file);
    }
    
    console.log('\n✅ All migrations applied successfully.');
  } catch (error: any) {
    console.error('\n❌ Migration process failed:', error.message);
    process.exit(1);
  }
}

// Run migrations if this script is executed directly
if (require.main === module) {
  runMigrations()
    .then(() => {
      process.exit(0);
    })
    .catch((error) => {
      console.error('Fatal error:', error);
      process.exit(1);
    });
}

export { runMigrations };

