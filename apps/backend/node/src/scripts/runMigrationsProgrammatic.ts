import Database from '../services/database';
import fs from 'fs';
import path from 'path';

// Find migrations directory - check multiple possible locations
// 1. Relative to current working directory (production: /app)
// 2. Relative to script location (development: apps/backend/node)
// 3. Relative to dist folder (if running from dist/)
function findMigrationsDir(): string {
  const possiblePaths = [
    path.resolve(process.cwd(), 'migrations'),
    path.resolve(__dirname, '../../migrations'),
    path.resolve(process.cwd(), '../migrations'),
  ];
  
  for (const dirPath of possiblePaths) {
    if (fs.existsSync(dirPath)) {
      return dirPath;
    }
  }
  
  // If none found, return the most likely path for better error message
  return path.resolve(process.cwd(), 'migrations');
}

const migrationsDir = findMigrationsDir();
if (!fs.existsSync(migrationsDir)) {
  console.error(`ERROR: Migrations directory not found. Checked:`);
  console.error(`  - ${path.resolve(process.cwd(), 'migrations')}`);
  console.error(`  - ${path.resolve(__dirname, '../../migrations')}`);
  console.error(`  - ${path.resolve(process.cwd(), '../migrations')}`);
  console.error(`Current working directory: ${process.cwd()}`);
  console.error(`Script location: ${__dirname}`);
  process.exit(1);
}

console.log(`Using migrations directory: ${migrationsDir}`);

// Create migrations tracking table if it doesn't exist
async function ensureMigrationsTable() {
  try {
    await Database.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id SERIAL PRIMARY KEY,
        filename TEXT NOT NULL UNIQUE,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
  } catch (error: any) {
    // If table creation fails, log but continue - might already exist or permission issue
    if (error.code === '42P07') {
      // Table already exists - that's fine
      console.log('Migrations tracking table already exists');
    } else {
      console.warn('Warning: Could not ensure migrations table exists:', error.message);
      // Continue anyway - migrations might still work
    }
  }
}

// Check if a migration has already been applied
async function isMigrationApplied(filename: string): Promise<boolean> {
  try {
    const result = await Database.query(
      'SELECT 1 FROM schema_migrations WHERE filename = $1',
      [filename]
    );
    return result.rows.length > 0;
  } catch (error: any) {
    // If table doesn't exist or query fails, assume migration not applied
    // This allows migrations to run even if tracking table can't be created
    if (error.code === '42P01') {
      // Table doesn't exist
      return false;
    }
    // Other error - log but assume not applied to be safe
    console.warn(`Warning: Could not check if migration ${filename} is applied:`, error.message);
    return false;
  }
}

// Mark a migration as applied
async function markMigrationApplied(filename: string) {
  try {
    await Database.query(
      'INSERT INTO schema_migrations (filename) VALUES ($1)',
      [filename]
    );
  } catch (error: any) {
    // If we can't mark as applied, log but don't fail
    // This allows migrations to complete even if tracking fails
    if (error.code === '42P01') {
      console.warn(`Warning: Could not mark migration ${filename} as applied (tracking table doesn't exist)`);
    } else if (error.code === '23505') {
      // Unique constraint violation - migration already marked, that's fine
      console.log(`Migration ${filename} already marked as applied`);
    } else {
      console.warn(`Warning: Could not mark migration ${filename} as applied:`, error.message);
    }
  }
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
    console.error('Error code:', error.code);
    console.error('Error message:', error.message);
    if (error.detail) {
      console.error('Error detail:', error.detail);
    }
    if (error.hint) {
      console.error('Error hint:', error.hint);
    }
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
    
    // Verify critical tables exist
    console.log('\nVerifying critical tables exist...');
    const tablesToCheck = ['user_profiles', 'diary_entries', 'schema_migrations'];
    for (const tableName of tablesToCheck) {
      try {
        const result = await Database.query(
          `SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = $1`,
          [tableName]
        );
        if (result.rows.length > 0) {
          console.log(`✅ Table '${tableName}' exists`);
        } else {
          console.error(`❌ Table '${tableName}' does NOT exist`);
        }
      } catch (error: any) {
        console.error(`⚠️  Could not verify table '${tableName}':`, error.message);
      }
    }
  } catch (error: any) {
    console.error('\n❌ Migration process failed:', error.message);
    if (error.stack) {
      console.error('Stack trace:', error.stack);
    }
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

