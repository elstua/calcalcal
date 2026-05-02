import app from './app';
import { runMigrations } from './scripts/runMigrationsProgrammatic';
import { AIAnalysisWorker } from './services/ai/analysisWorker';

const PORT = process.env.PORT ? Number(process.env.PORT) : 3000;

// Run migrations on startup (only in production or when RUN_MIGRATIONS env var is set)
const shouldRunMigrations = process.env.NODE_ENV === 'production' || process.env.RUN_MIGRATIONS === 'true';

async function startServer() {
  if (shouldRunMigrations) {
    console.log('Running database migrations...');
    try {
      await runMigrations();
      console.log('✅ Migrations completed successfully');
    } catch (error: any) {
      console.error('❌ Migration failed:', error.message);
      console.error('Server startup aborted. Please fix migration issues before starting the server.');
      // In production, fail fast - don't start server with broken database
      process.exit(1);
    }
  }

  app.listen(PORT, () => {
    console.log(`✅ Server running on http://localhost:${PORT}`);
    AIAnalysisWorker.start();
  });
}

startServer().catch((error) => {
  console.error('Failed to start server:', error);
  process.exit(1);
});
