# CalCalCal Backend — Development Guide

Express + TypeScript + PostgreSQL API server.

## Commands

```bash
npm run dev            # Dev server with hot reload (ts-node)
npm run build          # Compile TypeScript
npm start              # Run compiled JS (dist/server.js)
npm test               # Jest tests (src/test/**/*.test.ts)
npm run migrate:dev    # Run SQL migrations (ts-node)
npm run migrate        # Run SQL migrations (compiled)
npm run cleanup-images # Remove orphaned images from R2
```

### Docker (local dev)
```bash
docker-compose -f docker-compose.dev.yml up -d     # Start PostgreSQL + API
docker-compose -f docker-compose.dev.yml logs -f api
docker-compose -f docker-compose.dev.yml down
docker-compose -f docker-compose.dev.yml down -v    # + delete data
```

## Directory Structure

```
src/
  server.ts                    # Entry point — starts Express on PORT
  app.ts                       # Express app setup, middleware, route mounting
  middleware/
    auth.ts                    # authenticateToken middleware, AuthRequest type
  routes/
    auth.ts                    # /api/auth/* — login, signup, refresh, Google OAuth, delete account
    diary.ts                   # /api/diary/* — CRUD for diary entries and blocks
    ai.ts                      # /api/ai/* — analyze text, analyze-block (with image support)
    storage.ts                 # /api/storage/* — image upload/download (presigned URLs)
    streaks.ts                 # /api/streaks/* — get/recalculate user streaks
  models/
    User.ts                    # User CRUD — findById, findByEmail, findByAppleId, findByGoogleId, create, update, delete
    DiaryEntry.ts              # Diary entries + blocks — CRUD, findByDate, bulk operations
    RefreshToken.ts            # Refresh token storage and rotation
    AIAnalysisCache.ts         # Cache AI nutrition analysis results
    Streaks.ts                 # Streak data — get, update, recalculate
  services/
    auth.ts                    # JWT token generation (access + refresh), verification
    database.ts                # PostgreSQL connection pool (pg)
    calorieCalculator.ts       # Legacy calorie service (deprecated)
    streakCalculator.ts        # Streak calculation logic
    ai/
      service.ts               # AI service coordinator — routes to provider, handles caching
      prompts/
        index.ts               # Prompt builder
        templates.ts           # Prompt templates for nutrition analysis
      providers/
        index.ts               # Provider factory
        openai.ts              # OpenAI provider (GPT-4o)
        gemini.ts              # Google Gemini provider
        types.ts               # Provider interface
      prompt/
        index.ts               # (alternate prompt path)
    storage/
      r2.ts                    # Cloudflare R2 via MinIO client — upload, download, presigned URLs
  scripts/
    runMigrations.ts           # Run SQL migrations (dev, via ts-node)
    runMigrationsProgrammatic.ts # Run SQL migrations (production, compiled)
    cleanup-images.ts          # Delete orphaned images from R2
  test/
    auth-delete-account.test.ts
    streaks.test.ts
    streak_rewrite.test.ts
    debug_streak.test.ts
  types/
    google-genai-node.d.ts     # Type declarations for @google/genai
migrations/
  001_init.sql                 # Users, diary_entries, diary_blocks, ai_analysis_cache
  002_refresh_tokens.sql
  003_add_user_health_fields.sql
  004_add_google_id_field.sql
  005_add_onboarding_completed.sql
  006_add_temporary_account_support.sql
  007_add_streaks_tables.sql
  008_fix_streak_function.sql
  009_remove_streak_trigger.sql
  010_rewrite_streaks_logic.sql
  011_update_activity_levels.sql
```

## Key Dependencies

- **express** — HTTP framework
- **pg** — PostgreSQL client
- **jsonwebtoken** / **jose** — JWT auth
- **openai** — OpenAI API client
- **@google/genai** — Google Gemini API client
- **minio** — S3-compatible client for Cloudflare R2
- **multer** — Multipart file upload handling

## Architecture Notes

- **Auth flow**: Apple/Google Sign-In → backend verifies identity token → issues JWT access + refresh tokens. Temporary accounts get auto-generated credentials.
- **AI analysis**: Text (and optional images) sent to `/api/ai/analyze-block`. Service checks cache first, then routes to configured provider (OpenAI or Gemini). Results are cached by content hash.
- **Image storage**: Images uploaded via `/api/storage/upload` → stored in Cloudflare R2 → served via presigned URLs.
- **Streaks**: Calculated server-side from diary entry dates. `streakCalculator.ts` handles the logic, `Streaks` model persists state.
- **Migrations**: Sequential SQL files in `migrations/`. Run with `npm run migrate:dev`. Always add new migrations with the next number prefix.

## Environment Configuration

### Local Dev
Docker Compose (`docker-compose.dev.yml`) runs two containers:
- **PostgreSQL 15** — `postgres:postgres@localhost:5432/calcalcal_dev`
- **API** — hot-reload via `npm run dev`, source mounted as read-only volume

Secrets loaded from `.env.local` (copy `.env.example`). Key env vars:
```
NODE_ENV=development
PORT=3000
DATABASE_URL=postgresql://postgres:postgres@postgres:5432/calcalcal_dev
JWT_SECRET=<any string>
OPENAI_API_KEY=sk-...       # or GEMINI_API_KEY
AI_PROVIDER=openai           # or gemini
R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET, R2_PUBLIC_BASE_URL
```

### Production
Docker Compose (`docker-compose.production.yml`) on VPS, behind nginx reverse proxy:
- **PostgreSQL 15** — `calcalcal:***@postgres:5432/calcalcal_production`, port bound to `127.0.0.1` only
- **API** — compiled JS (`Dockerfile`), port `127.0.0.1:3000` (nginx proxies `api.calcalcal.app` → `localhost:3000`)
- Both containers have resource limits (1 CPU, 1GB RAM)
- Health checks on both services
- Secrets in `.env.production` (copy `.env.production.template`)

Additional production env vars beyond local:
```
AI_OPENAI_MODEL=gpt-4o-mini
AI_GEMINI_MODEL=gemini-2.5-flash
AI_TEMPERATURE=0.2
AI_PROMPT_VERSION=v1
AI_MAX_CONCURRENCY=3
AI_PROVIDER_TIMEOUT_MS=45000
PUBLIC_BASE_URL=https://api.calcalcal.app
DB_POOL_MAX=5
```

## Code Patterns

- All routes use `authenticateToken` middleware — access `req.userId` via `AuthRequest` type
- Parameterized SQL queries everywhere (never interpolate user input)
- `try/catch` on all async route handlers, structured JSON error responses
- Group imports: express, services, models, types
- Strict TypeScript (`strict: true`), interfaces for all request/response shapes
