# Backend (Node.js + PostgreSQL) – Current Setup

This document describes the current backend architecture, endpoints, auth model, database integration, AI flow, configuration, and how the iOS app integrates with it.

## Overview

- **Runtime**: Node.js (Express)
- **Database**: PostgreSQL (managed or local)
- **Auth**: Apple Sign-In for initial identity, JWT access/refresh tokens for session
- **AI**: Provider abstraction (OpenAI by default) for nutrition extraction; with result caching
- **Endpoints base**: `/api/*`
- **Health**: `/health`

Startup and system wiring:

```129:156:apps/backend/node/src/app.ts
app.get('/health', (_req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/diary', diaryRoutes);
app.use('/api/ai', aiRoutes);
```

On boot, the server optionally runs migrations (production or `RUN_MIGRATIONS=true`) then listens on `PORT`:

```1:15:apps/backend/node/src/server.ts
import { runMigrations } from './scripts/runMigrationsProgrammatic';
const PORT = process.env.PORT ? Number(process.env.PORT) : 3000;
const shouldRunMigrations = process.env.NODE_ENV === 'production' || process.env.RUN_MIGRATIONS === 'true';
```

## Configuration

Environment variables (see `apps/backend/node/ENV.example`):

- **Server**: `PORT`
- **Auth**: `JWT_SECRET` (required), optional `APPLE_AUDIENCE`
- **Database**: `DATABASE_URL` (PostgreSQL URI); optional `DB_POOL_MAX`
- **AI**: `OPENAI_API_KEY`, `AI_PROVIDER` (default: `openai`), `AI_OPENAI_MODEL` (default: `gpt-4o-mini`), `AI_TEMPERATURE` (default: `0.2`), `AI_PROMPT_VERSION` (default: `v1`)

Database connection and SSL handling (DigitalOcean compatible):

```12:21:apps/backend/node/src/services/database.ts
let connectionString = process.env.DATABASE_URL || 'postgresql://localhost:5432/calcalcal_dev';
// ... validates format and parses SSL params; removes sslmode and applies ssl config when needed
```

## Authentication & Sessions

Flow:
1. iOS obtains an Apple identity token.
2. iOS calls backend `POST /api/auth/signin-apple` with `{ identityToken, user }`.
3. Backend verifies Apple token (best-effort), finds or creates a user, then issues JWT `access_token` and `refresh_token`.
4. iOS stores tokens securely and sends `Authorization: Bearer <access_token>` for authenticated endpoints.
5. When access token expires, iOS calls `POST /api/auth/refresh` with `refresh_token` to rotate tokens.

Endpoints:

- `POST /api/auth/signin-apple`
- `POST /api/auth/refresh`
- `GET /api/auth/profile`
- `POST /api/auth/logout` (revoke one or all refresh tokens)

Selected implementation snippets:

```10:31:apps/backend/node/src/routes/auth.ts
router.post('/signin-apple', async (req: Request, res: Response) => {
  const { identityToken, user: userInfo } = req.body || {};
  // verify apple token (best-effort), upsert user, generate tokens, persist refresh token
});
```

```22:44:apps/backend/node/src/services/auth.ts
static generateSessionTokens(userId: string) {
  const secret = process.env.JWT_SECRET;
  const accessToken = jwt.sign({ userId, type: 'access' }, secret, { expiresIn: '7d' });
  const refreshToken = jwt.sign({ userId, type: 'refresh' }, secret, { expiresIn: '30d' });
  return { accessToken, refreshToken };
}
```

Auth middleware for protected routes:

```8:17:apps/backend/node/src/middleware/auth.ts
export function authenticateToken(req: AuthRequest, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  const token = authHeader?.startsWith('Bearer ') ? authHeader.substring(7) : null;
  // verify token and set req.userId
}
```

Refresh token storage and rotation:

```20:33:apps/backend/node/src/models/RefreshToken.ts
static async create(userId: string, rawToken: string, expiresAt: Date, opts?: { userAgent?: string; ipAddress?: string })
```

## Diary API

All endpoints require `Authorization: Bearer <access_token>`.

- `GET /api/diary/entries?dateFrom=YYYY-MM-DD&dateTo=YYYY-MM-DD` – list by date range (current user)
- `GET /api/diary/entries/:id` – get one entry (must belong to the user)
- `POST /api/diary/entries` – upsert by `(user_id, date)`; body `{ date, content }`
- `PATCH /api/diary/entries/:id` – update content
- `DELETE /api/diary/entries/:id` – delete entry

Query and persistence examples:

```24:37:apps/backend/node/src/models/DiaryEntry.ts
static async listByDateRange(userId: string, dateFrom: string, dateTo: string) {
  return Database.query(`SELECT id, user_id, date, content, images, total_calories, updated_at
                         FROM diary_entries WHERE user_id = $1 AND date >= $2 AND date <= $3
                         ORDER BY date DESC`, [userId, dateFrom, dateTo]);
}
```

## AI Analysis

- `POST /api/ai/analyze` – accepts `{ entryId, blocks }` and returns `{ success, updatedBlocksCount }`.
- Updates `diary_entries` with analyzed block metrics and sets `ai_analysis_status`.
- Caches per-block results by content hash to avoid re-analyzing identical text.

```11:31:apps/backend/node/src/routes/ai.ts
router.post('/analyze', async (req: AuthRequest, res) => {
  // validate, set status=processing, analyze with AIService, write results and totals, set status=completed
});
```

Provider and caching flow:

```7:13:apps/backend/node/src/services/ai/service.ts
const provider = getNutritionProvider();
const model = process.env.AI_OPENAI_MODEL || 'gpt-4o-mini';
```

```9:15:apps/backend/node/src/models/AIAnalysisCache.ts
SELECT analysis_result, confidence FROM ai_analysis_cache WHERE content_hash = $1
```

## Database

Migrations live in `apps/backend/node/migrations/`. On production start (or `RUN_MIGRATIONS=true`), `runMigrationsProgrammatic` applies them before the server binds to the port.

Key tables (see `001_init.sql`):

- `user_profiles` – user data (id, email, name, apple_id, goals…)
- `diary_entries` – per-day diary with derived nutrition totals and `blocks`
- `ai_analysis_cache` – cached AI results by content hash
- `refresh_tokens` – stored, hashed refresh tokens for rotation and revocation

Triggers and helper functions compute derived totals on content changes for robustness.

## iOS Integration

Base URL is configured via `API_URL` in Info.plist and used through `Configuration.apiURL`.

Client calls:

- Auth (`AuthManager.swift`):
  - `POST /api/auth/signin-apple`
  - `POST /api/auth/refresh`
  - `GET /api/auth/profile`
- Diary (`DiaryAPI.swift`):
  - `GET /api/diary/entries` with `dateFrom`/`dateTo`
  - `GET /api/diary/entries/:id`
  - `POST /api/diary/entries` (create/upsert)
  - `PATCH /api/diary/entries/:id` (update)
  - `DELETE /api/diary/entries/:id`
- AI:
  - `POST /api/ai/analyze`

All authenticated requests include `Authorization: Bearer <access_token>` and `Content-Type: application/json` when a body is present.

## Local Development

From `apps/backend/node/`:

- `npm run dev` – start server with ts-node
- `npm run build && npm start` – compile and run from `dist/`
- `npm run migrate` – run SQL migrations (CLI)

Docker example: see `docker-compose.yml` (exposes `3000`, reads `.env.local`).

## Deployment Notes

- Ensure `DATABASE_URL` uses a full PostgreSQL URI (for DO managed DBs, copy exact connection string; do not leave `${...}` references).
- Set `JWT_SECRET` and `OPENAI_API_KEY` securely.
- For DO managed databases, SSL is auto-enabled with `rejectUnauthorized: false` in the pool config.
- Optionally set `RUN_MIGRATIONS=true` for boot-time migrations in production.

## Error Handling & Health

- All API errors are JSON; no HTML error pages.
- `/health` returns `{ status: "ok", timestamp }` for uptime probes.


