import app from './app';
import { runMigrations } from './scripts/runMigrationsProgrammatic';

const PORT = process.env.PORT ? Number(process.env.PORT) : 3000;

// Run migrations on startup (only in production or when RUN_MIGRATIONS env var is set)
const shouldRunMigrations = process.env.NODE_ENV === 'production' || process.env.RUN_MIGRATIONS === 'true';

async function startServer() {
  if (shouldRunMigrations) {
    console.log('Running database migrations...');
    try {
      await runMigrations();
    } catch (error: any) {
      console.error('⚠️  Migration failed, but continuing server startup:', error.message);
      // In production, you might want to exit here instead
      // process.exit(1);
    }
  }

  app.listen(PORT, () => {
    console.log(`✅ Server running on http://localhost:${PORT}`);
  });
}

startServer().catch((error) => {
  console.error('Failed to start server:', error);
  process.exit(1);
});
