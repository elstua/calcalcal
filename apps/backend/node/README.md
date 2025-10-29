# CalCalCal Backend (Node.js + Express + PostgreSQL)

## Quick Start

```bash
cd apps/backend/node

# 1) Create your env file
cp .env.example .env.local

# 2) Install dependencies
npm install

# 3) Start dev server
npm run dev

# Health check
curl http://localhost:3000/health
```

## Project Structure

```
src/
  app.ts              # Express app (middleware + routes)
  server.ts           # Bootstrap (reads PORT, starts server)
  services/
    database.ts       # PostgreSQL connection pool helper
  routes/             # (to be added in next phases)
  models/             # (to be added in next phases)
  middleware/         # (to be added in next phases)
```

## Environment Variables

See `.env.example` for all required variables. For local dev, create `.env.local`.

- `PORT`: API port (default 3000)
- `DATABASE_URL`: PostgreSQL connection string
- `JWT_SECRET`: Secret for signing JWTs (to be used in auth phase)
- `OPENAI_API_KEY`: For AI analysis (AI phase)
- `REDIS_URL`: Optional, for background jobs

### Supabase environment mapping

You can reuse the same Supabase environment in this Node service. Copy the following from your Supabase project (dashboard) or local CLI into your `.env.local`:

- `SUPABASE_URL` → your project URL (local default: `http://127.0.0.1:54321`)
- `SUPABASE_ANON_KEY` → anon public key
- `SUPABASE_SERVICE_ROLE_KEY` → service role key (keep secret)
- `SUPABASE_AUTH_EXTERNAL_APPLE_SECRET` → Apple provider secret (if configured)

Optional (if used by your Supabase config):

- `OPENAI_API_KEY` (also referenced by Supabase Studio)
- `S3_HOST`, `S3_REGION`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`
- `SUPABASE_AUTH_SMS_TWILIO_AUTH_TOKEN`

Local development convenience:

```bash
cd apps/backend/node
cp ENV.example .env.local
# then paste your Supabase values into .env.local
```

## Next Steps

- Add auth routes (Apple Sign-In) under `src/routes`
- Add diary CRUD routes under `src/routes`
- Add AI analysis endpoint under `src/routes`
- Configure production deploy (DigitalOcean App Platform)
```
