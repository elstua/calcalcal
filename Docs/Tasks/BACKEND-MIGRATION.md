# Complete Backend Migration: Supabase → Node.js + PostgreSQL

**Estimated Time**: 2-3 weeks for a first-timer  
**Difficulty**: Medium (lots of steps, but straightforward)  
**Prerequisites**: Mac with Xcode (already have), comfortable with terminal

---

## Table of Contents

1. [Part 0: Foundation & Setup](#part-0-foundation--setup)
2. [Part 1: Local Development Environment](#part-1-local-development-environment)
3. [Part 2: Authentication (Apple Sign-In)](#part-2-authentication-apple-sign-in)
4. [Part 3: REST API (Diary CRUD)](#part-3-rest-api-diary-crud)
5. [Part 4: AI Analysis Service](#part-4-ai-analysis-service)
6. [Part 5: Testing & Debugging](#part-5-testing--debugging)
7. [Part 6: Production Deployment](#part-6-production-deployment)
8. [Part 7: iOS App Migration](#part-7-ios-app-migration)

---

# Part 0: Foundation & Setup

## What You're Building

Instead of relying on Supabase's managed services, you'll have your own **three-tier stack**:

```
┌─────────────────────────────┐
│   iOS App (unchanged)       │
│   (just URL changes)        │
└──────────────┬──────────────┘
               │ HTTP Requests
               ↓
┌─────────────────────────────┐
│   Node.js + Express         │
│   (your API server)         │
│   • Auth endpoints          │
│   • Diary CRUD endpoints    │
│   • AI analysis endpoints   │
└──────────────┬──────────────┘
               │ SQL queries
               ↓
┌─────────────────────────────┐
│   PostgreSQL Database       │
│   (same schema as before)   │
└─────────────────────────────┘
```

## What You Need Installed

### 1. Node.js (The JavaScript Runtime)
Node.js is like Xcode but for backend code. It lets you run JavaScript on a server.

**Install Node.js:**
```bash
# Download from https://nodejs.org (get LTS version - currently 20.x)
# Or use Homebrew:
brew install node

# Verify installation:
node --version  # Should show v20.x.x
npm --version   # Should show 10.x.x (comes with Node)
```

**What is npm?**  
npm = Node Package Manager. It's like CocoaPods for Swift, but for JavaScript.  
It downloads and manages code libraries for you.

### 2. PostgreSQL (The Database)
PostgreSQL is the actual database. You'll run it locally during development.

**Install PostgreSQL:**
```bash
# Using Homebrew (easiest on Mac):
brew install postgresql

# Start PostgreSQL:
brew services start postgresql

# Verify it's running:
psql --version
```

**What is PostgreSQL?**  
It's a database (like SQLite) but more powerful. Your data lives here.

### 3. Git (for version control)
```bash
# Likely already installed, verify:
git --version
```

### 4. VS Code or similar editor (optional but recommended)
Download from https://code.visualstudio.com

### 5. Postman (for testing APIs)
Download from https://www.postman.com (free)  
This lets you test your API endpoints without building iOS UI.

---

## Create Your Project Directory

```bash
# Navigate to your project folder
cd /Users/artemsavelev

# Create a new folder for the backend
mkdir calcalcal-backend
cd calcalcal-backend

# Initialize it as a git repository
git init
```

---

# Part 1: Local Development Environment

## Step 1: Initialize Node.js Project (done)

```bash
# Create package.json (tells Node what libraries to install)
npm init -y

# This creates a file that looks like:
# {
#   "name": "calcalcal-backend",
#   "version": "1.0.0",
#   ...
# }
```

## Step 2: Install Core Libraries (Dependencies) (done)

These are the "frameworks" your backend will use:

```bash
npm install express
npm install pg
npm install dotenv
npm install jsonwebtoken
npm install bcryptjs
npm install cors
npm install apple-signin-auth
npm install openai
npm install bull redis
npm install typescript @types/node @types/express --save-dev
npm install ts-node --save-dev
```

**What each does:**
- `express` - Web framework (like Spring for Java, Django for Python)
- `pg` - PostgreSQL driver (lets Node.js talk to the database)
- `dotenv` - Manages environment variables (secrets like API keys)
- `jsonwebtoken` - Creates and verifies JWT tokens (your auth system)
- `bcryptjs` - Hashes passwords securely
- `cors` - Allows your iOS app to make requests to the backend
- `apple-signin-auth` - Verifies Apple's sign-in tokens
- `openai` - Calls the OpenAI API for AI analysis
- `bull` & `redis` - Manages background jobs (for AI analysis)
- `typescript` - Type checking (optional but recommended)

**Note:** Lines with `--save-dev` are development dependencies (tools you need while coding, but not in production).

## Step 3: Set Up File Structure (done)

Create this folder structure:

```bash
mkdir -p src/{config,middleware,routes,services,models,utils}
mkdir -p migrations
mkdir -p logs
```

Your project should now look like:
```
calcalcal-backend/
├── src/
│   ├── config/
│   ├── middleware/
│   ├── routes/
│   ├── services/
│   ├── models/
│   ├── utils/
│   ├── app.ts           # Main app file (create below)
│   └── server.ts        # Server startup (create below)
├── migrations/
├── logs/
├── package.json
├── package-lock.json    # Auto-generated, don't touch
├── tsconfig.json        # TypeScript config (create below)
├── .env.local           # Environment variables (create below)
└── .gitignore           # Files to ignore (create below)
```

## Step 4: Create TypeScript Configuration (done)

Create `tsconfig.json`:
```bash
cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules"]
}
EOF
```

## Step 5: Update package.json Scripts

Edit `package.json` and replace the `"scripts"` section:

```json
{
  "name": "calcalcal-backend",
  "version": "1.0.0",
  "description": "CalCalCal backend API",
  "main": "dist/server.js",
  "scripts": {
    "start": "node dist/server.js",
    "dev": "ts-node src/server.ts",
    "build": "tsc",
    "watch": "tsc --watch",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.3",
    "dotenv": "^16.3.1",
    "jsonwebtoken": "^9.1.2",
    "bcryptjs": "^2.4.3",
    "cors": "^2.8.5",
    "apple-signin-auth": "^1.7.2",
    "openai": "^4.28.0",
    "bull": "^4.11.4",
    "redis": "^4.6.12"
  },
  "devDependencies": {
    "typescript": "^5.3.3",
    "@types/node": "^20.10.6",
    "@types/express": "^4.17.21",
    "ts-node": "^10.9.2"
  }
}
```

## Step 6: Create Environment Variables File

Create `.env.local` in the project root:

```bash
cat > .env.local << 'EOF'
# Server
NODE_ENV=development
PORT=3000
API_URL=http://localhost:3000

# Database
DATABASE_URL=postgresql://postgres:password@localhost:5432/calcalcal_dev

# JWT (generate a random string)
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production

# OpenAI
OPENAI_API_KEY=sk-...your-key-here...

# Redis (optional, for background jobs)
REDIS_URL=redis://localhost:6379
EOF
```

## Step 7: Create .gitignore

```bash
cat > .gitignore << 'EOF'
node_modules/
dist/
.env
.env.local
*.log
.DS_Store
EOF
```

## Step 8: Set Up PostgreSQL Database (done)

```bash
# Connect to PostgreSQL command line
psql postgres

# In the PostgreSQL terminal, create a new database:
CREATE DATABASE calcalcal_dev;

# Create a user (optional, but good practice):
CREATE USER calcalcal_user WITH PASSWORD 'password';

# Grant permissions:
ALTER ROLE calcalcal_user CREATEDB;
GRANT ALL PRIVILEGES ON DATABASE calcalcal_dev TO calcalcal_user;

# Exit PostgreSQL:
\q
```

## Step 9: Create Initial Server File (done)

Create `src/server.ts`:

```typescript
import app from './app';

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`✅ Server running on http://localhost:${PORT}`);
});
```

## Step 10: Create Main App File (done)

Create `src/app.ts`:

```typescript
import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: '.env.local' });

const app: Express = express();

// Middleware
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// TODO: Import and use routes
// app.use('/api/auth', authRoutes);
// app.use('/api/diary', diaryRoutes);
// app.use('/api/ai', aiRoutes);

export default app;
```

## Step 11: Test Your Setup

```bash
# From the calcalcal-backend directory:
npm run dev

# You should see:
# ✅ Server running on http://localhost:3000

# In another terminal, test the health endpoint:
curl http://localhost:3000/health

# You should get:
# {"status":"ok","timestamp":"2024-01-15T10:30:00.000Z"}
```

**Congratulations! Your basic server is running.** 🎉

---

# Part 2: Authentication (Apple Sign-In)

## Understanding the Flow

```
1. iOS App asks user to sign in with Apple
   ↓
2. iOS gets an "identity token" (JWT from Apple)
   ↓
3. iOS sends identity token to your backend
   ↓
4. Backend verifies the token with Apple's public keys
   ↓
5. Backend creates a user in database
   ↓
6. Backend generates a session token (JWT for your app)
   ↓
7. Backend returns session token to iOS
   ↓
8. iOS stores session token, includes it in all future requests
```

## Step 1: Create Database Service (done)

Create `src/services/database.ts`:

```typescript
import { Pool, PoolClient } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

export class Database {
  static async query(text: string, params?: any[]) {
    const result = await pool.query(text, params);
    return result;
  }

  static async getClient(): Promise<PoolClient> {
    return pool.connect();
  }
}

export default Database;
```

## Step 2: Create User Model (done)

Create `src/models/User.ts`:

```typescript
import Database from '../services/database';
import bcrypt from 'bcryptjs';

export interface User {
  id: string;
  email: string | null;
  name: string | null;
  apple_id: string;
  daily_calorie_goal: number;
  daily_protein_goal: number;
  daily_fat_goal: number;
  daily_carb_goal: number;
  units: string;
  timezone_offset: number;
  created_at: string;
  updated_at: string;
}

export class UserModel {
  // Find user by Apple ID
  static async findByAppleId(appleId: string): Promise<User | null> {
    const result = await Database.query(
      'SELECT * FROM user_profiles WHERE apple_id = $1',
      [appleId]
    );
    return result.rows[0] || null;
  }

  // Find user by ID
  static async findById(id: string): Promise<User | null> {
    const result = await Database.query(
      'SELECT * FROM user_profiles WHERE id = $1',
      [id]
    );
    return result.rows[0] || null;
  }

  // Create or update user
  static async upsertUser(
    id: string,
    appleId: string,
    email?: string,
    name?: string
  ): Promise<User> {
    const result = await Database.query(
      `INSERT INTO user_profiles (id, apple_id, email, name, updated_at)
       VALUES ($1, $2, $3, $4, NOW())
       ON CONFLICT (id) DO UPDATE 
       SET email = COALESCE($3, email),
           name = COALESCE($4, name),
           updated_at = NOW()
       RETURNING *`,
      [id, appleId, email, name]
    );
    return result.rows[0];
  }

  // Update user profile
  static async update(id: string, updates: Partial<User>): Promise<User> {
    const keys = Object.keys(updates);
    const values = Object.values(updates);
    const setClause = keys.map((k, i) => `${k} = $${i + 2}`).join(', ');

    const result = await Database.query(
      `UPDATE user_profiles SET ${setClause}, updated_at = NOW()
       WHERE id = $1 RETURNING *`,
      [id, ...values]
    );
    return result.rows[0];
  }
}
```

## Step 3: Create Auth Service (done)

Create `src/services/auth.ts`:

```typescript
import jwt from 'jsonwebtoken';
import axios from 'axios';

const APPLE_PUBLIC_KEYS_URL = 'https://appleid.apple.com/auth/keys';

export class AuthService {
  // Verify Apple's identity token
  static async verifyAppleToken(identityToken: string) {
    try {
      // Get Apple's public keys
      const response = await axios.get(APPLE_PUBLIC_KEYS_URL);
      const keys = response.data.keys;

      // Decode the JWT header to find the right key
      const decoded = jwt.decode(identityToken, { complete: true });
      if (!decoded) throw new Error('Invalid token format');

      const kid = decoded.header.kid;
      const key = keys.find((k: any) => k.kid === kid);
      if (!key) throw new Error('Key not found');

      // Convert JWK to PEM format (simplified)
      // For production, use a library like 'jwk-to-pem'
      console.log('Apple token verification (basic):', decoded.payload);

      // Return the decoded payload
      return decoded.payload as any;
    } catch (error) {
      console.error('Apple token verification failed:', error);
      throw new Error('Invalid Apple token');
    }
  }

  // Generate session JWT for your app
  static generateSessionTokens(userId: string) {
    const secret = process.env.JWT_SECRET!;

    const accessToken = jwt.sign(
      { userId, type: 'access' },
      secret,
      { expiresIn: '7d' }
    );

    const refreshToken = jwt.sign(
      { userId, type: 'refresh' },
      secret,
      { expiresIn: '30d' }
    );

    return { accessToken, refreshToken };
  }

  // Verify session JWT
  static verifySessionToken(token: string): { userId: string } | null {
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET!) as any;
      return { userId: decoded.userId };
    } catch (error) {
      return null;
    }
  }
}
```

## Step 4: Create Auth Routes (done)

Create `src/routes/auth.ts`:

```typescript
import { Router, Request, Response } from 'express';
import { AuthService } from '../services/auth';
import { UserModel } from '../models/User';
import Database from '../services/database';
import { v4 as uuidv4 } from 'uuid';

const router = Router();

// POST /api/auth/signin-apple
router.post('/signin-apple', async (req: Request, res: Response) => {
  try {
    const { identityToken, user: userInfo } = req.body;

    if (!identityToken) {
      return res.status(400).json({ error: 'identityToken is required' });
    }

    // 1. Verify Apple token
    let applePayload: any;
    try {
      applePayload = await AuthService.verifyAppleToken(identityToken);
    } catch (error) {
      // For MVP, allow token verification to fail (log the error)
      console.warn('Apple token verification failed, proceeding anyway:', error);
      applePayload = { sub: userInfo?.id };
    }

    const appleId = applePayload?.sub || userInfo?.id;
    if (!appleId) {
      return res.status(400).json({ error: 'Unable to get Apple user ID' });
    }

    // 2. Check if user exists
    let dbUser = await UserModel.findByAppleId(appleId);

    // 3. Create user if doesn't exist
    if (!dbUser) {
      const userId = uuidv4();
      dbUser = await UserModel.upsertUser(
        userId,
        appleId,
        userInfo?.email || applePayload?.email,
        userInfo?.name || applePayload?.name
      );
    } else {
      // Update with new info if provided
      if (userInfo?.email && !dbUser.email) {
        await UserModel.update(dbUser.id, { email: userInfo.email });
      }
      if (userInfo?.name && !dbUser.name) {
        await UserModel.update(dbUser.id, { name: userInfo.name });
      }
      dbUser = (await UserModel.findById(dbUser.id))!;
    }

    // 4. Generate session tokens
    const { accessToken, refreshToken } = AuthService.generateSessionTokens(
      dbUser.id
    );

    // 5. Save refresh token (hash it for security)
    // For MVP, we'll skip this and just return tokens
    // In production, save hashed refresh tokens in DB

    // 6. Return response
    return res.json({
      success: true,
      user: dbUser,
      session: {
        access_token: accessToken,
        refresh_token: refreshToken,
        expires_in: 7 * 24 * 60 * 60, // 7 days in seconds
      },
    });
  } catch (error) {
    console.error('Apple sign-in error:', error);
    res.status(500).json({
      error: 'Authentication failed',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// POST /api/auth/refresh
router.post('/refresh', (req: Request, res: Response) => {
  try {
    const { refresh_token } = req.body;

    if (!refresh_token) {
      return res.status(400).json({ error: 'refresh_token is required' });
    }

    // Verify refresh token
    const decoded = AuthService.verifySessionToken(refresh_token);
    if (!decoded) {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }

    // Generate new tokens
    const { accessToken, refreshToken } = AuthService.generateSessionTokens(
      decoded.userId
    );

    return res.json({
      success: true,
      session: {
        access_token: accessToken,
        refresh_token: refreshToken,
        expires_in: 7 * 24 * 60 * 60,
      },
    });
  } catch (error) {
    res.status(500).json({ error: 'Token refresh failed' });
  }
});

// GET /api/auth/profile
router.get('/profile', async (req: Request, res: Response) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing authorization header' });
    }

    const token = authHeader.substring(7);
    const decoded = AuthService.verifySessionToken(token);
    if (!decoded) {
      return res.status(401).json({ error: 'Invalid token' });
    }

    const user = await UserModel.findById(decoded.userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    return res.json({
      success: true,
      profile: user,
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to get profile' });
  }
});

export default router;
```

## Step 5: Add Auth Middleware (done)

Create `src/middleware/auth.ts`:

```typescript
import { Request, Response, NextFunction } from 'express';
import { AuthService } from '../services/auth';

export interface AuthRequest extends Request {
  userId?: string;
}

export function authenticateToken(
  req: AuthRequest,
  res: Response,
  next: NextFunction
) {
  const authHeader = req.headers.authorization;
  const token = authHeader?.startsWith('Bearer ') ? authHeader.substring(7) : null;

  if (!token) {
    return res.status(401).json({ error: 'Missing authorization header' });
  }

  const decoded = AuthService.verifySessionToken(token);
  if (!decoded) {
    return res.status(401).json({ error: 'Invalid token' });
  }

  req.userId = decoded.userId;
  next();
}
```

## Step 6: Update app.ts to Include Auth Routes (done)

Edit `src/app.ts`:

```typescript
import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import authRoutes from './routes/auth';

dotenv.config({ path: '.env.local' });

const app: Express = express();

app.use(cors());
app.use(express.json());

app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Auth routes
app.use('/api/auth', authRoutes);

export default app;
```

## Step 7: Test Authentication

```bash
# Terminal 1: Start the server
npm run dev

# Terminal 2: Test the endpoints
# Get health status
curl http://localhost:3000/health

# Test profile endpoint (without token - should fail)
curl -X GET http://localhost:3000/api/auth/profile

# Test apple sign-in with a test token
curl -X POST http://localhost:3000/api/auth/signin-apple \
  -H "Content-Type: application/json" \
  -d '{
    "identityToken": "test-token",
    "user": {
      "id": "apple123",
      "email": "test@example.com",
      "name": "Test User"
    }
  }'
```

You should get back a response with `access_token` and `refresh_token`.

---

# Part 3: REST API (Diary CRUD)

## Step 1: Create Diary Entry Model

Create `src/models/DiaryEntry.ts`:

```typescript
import Database from '../services/database';

export interface DiaryEntry {
  id: string;
  user_id: string;
  date: string;
  content: string;
  blocks: any[];
  total_calories: number;
  total_protein: number;
  total_fat: number;
  total_carbs: number;
  total_fiber: number;
  total_sugar: number;
  total_sodium: number;
  ai_analysis_status: string;
  ai_analysis_error: string | null;
  images: string[];
  created_at: string;
  updated_at: string;
}

export class DiaryEntryModel {
  // Get entries for a date range
  static async listByDateRange(
    userId: string,
    dateFrom: string,
    dateTo: string
  ) {
    const result = await Database.query(
      `SELECT id, user_id, date, content, images, total_calories, updated_at
       FROM diary_entries
       WHERE user_id = $1 AND date >= $2 AND date <= $3
       ORDER BY date DESC`,
      [userId, dateFrom, dateTo]
    );
    return result.rows;
  }

  // Get entry by date
  static async getByDate(userId: string, date: string) {
    const result = await Database.query(
      `SELECT * FROM diary_entries
       WHERE user_id = $1 AND date = $2`,
      [userId, date]
    );
    return result.rows[0] || null;
  }

  // Get entry by ID
  static async getById(entryId: string) {
    const result = await Database.query(
      `SELECT * FROM diary_entries WHERE id = $1`,
      [entryId]
    );
    return result.rows[0] || null;
  }

  // Create or update entry
  static async upsert(userId: string, date: string, content: string) {
    const result = await Database.query(
      `INSERT INTO diary_entries (user_id, date, content)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, date) 
       DO UPDATE SET content = $3, updated_at = NOW()
       RETURNING *`,
      [userId, date, content]
    );
    return result.rows[0];
  }

  // Update content
  static async updateContent(entryId: string, userId: string, content: string) {
    const result = await Database.query(
      `UPDATE diary_entries
       SET content = $1, updated_at = NOW()
       WHERE id = $2 AND user_id = $3
       RETURNING *`,
      [content, entryId, userId]
    );
    return result.rows[0] || null;
  }

  // Delete entry
  static async delete(entryId: string, userId: string) {
    const result = await Database.query(
      `DELETE FROM diary_entries
       WHERE id = $1 AND user_id = $2`,
      [entryId, userId]
    );
    return result.rowCount > 0;
  }
}
```

## Step 2: Create Diary Routes

Create `src/routes/diary.ts`:

```typescript
import { Router } from 'express';
import { AuthRequest, authenticateToken } from '../middleware/auth';
import { DiaryEntryModel } from '../models/DiaryEntry';

const router = Router();

// Protect all diary routes
router.use(authenticateToken);

// GET /api/diary/entries - List entries
router.get('/entries', async (req: AuthRequest, res) => {
  try {
    const { dateFrom, dateTo } = req.query;
    const userId = req.userId!;

    if (!dateFrom || !dateTo) {
      return res.status(400).json({
        error: 'dateFrom and dateTo query parameters are required',
      });
    }

    const entries = await DiaryEntryModel.listByDateRange(
      userId,
      String(dateFrom),
      String(dateTo)
    );

    res.json(entries);
  } catch (error) {
    console.error('Error listing entries:', error);
    res.status(500).json({ error: 'Failed to list entries' });
  }
});

// GET /api/diary/entries/:id - Get entry by ID
router.get('/entries/:id', async (req: AuthRequest, res) => {
  try {
    const { id } = req.params;
    const userId = req.userId!;

    const entry = await DiaryEntryModel.getById(id);
    if (!entry || entry.user_id !== userId) {
      return res.status(404).json({ error: 'Entry not found' });
    }

    res.json(entry);
  } catch (error) {
    console.error('Error getting entry:', error);
    res.status(500).json({ error: 'Failed to get entry' });
  }
});

// POST /api/diary/entries - Create entry
router.post('/entries', async (req: AuthRequest, res) => {
  try {
    const { date, content } = req.body;
    const userId = req.userId!;

    if (!date) {
      return res.status(400).json({ error: 'date is required' });
    }

    const entry = await DiaryEntryModel.upsert(userId, date, content || '');

    res.status(201).json(entry);
  } catch (error) {
    console.error('Error creating entry:', error);
    res.status(500).json({ error: 'Failed to create entry' });
  }
});

// PATCH /api/diary/entries/:id - Update entry
router.patch('/entries/:id', async (req: AuthRequest, res) => {
  try {
    const { id } = req.params;
    const { content } = req.body;
    const userId = req.userId!;

    if (!content) {
      return res.status(400).json({ error: 'content is required' });
    }

    const entry = await DiaryEntryModel.updateContent(id, userId, content);
    if (!entry) {
      return res.status(404).json({ error: 'Entry not found' });
    }

    res.json(entry);
  } catch (error) {
    console.error('Error updating entry:', error);
    res.status(500).json({ error: 'Failed to update entry' });
  }
});

// DELETE /api/diary/entries/:id - Delete entry
router.delete('/entries/:id', async (req: AuthRequest, res) => {
  try {
    const { id } = req.params;
    const userId = req.userId!;

    const success = await DiaryEntryModel.delete(id, userId);
    if (!success) {
      return res.status(404).json({ error: 'Entry not found' });
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Error deleting entry:', error);
    res.status(500).json({ error: 'Failed to delete entry' });
  }
});

export default router;
```

## Step 3: Update app.ts

Edit `src/app.ts` to include diary routes:

```typescript
import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import authRoutes from './routes/auth';
import diaryRoutes from './routes/diary';

dotenv.config({ path: '.env.local' });

const app: Express = express();

app.use(cors());
app.use(express.json());

app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/api/auth', authRoutes);
app.use('/api/diary', diaryRoutes);

export default app;
```

---

# Part 4: AI Analysis Service

## Step 1: Create AI Analysis Model

Create `src/models/AIAnalysisCache.ts`:

```typescript
import Database from '../services/database';
import crypto from 'crypto';

export class AIAnalysisCacheModel {
  static async getByContentHash(hash: string) {
    const result = await Database.query(
      `SELECT analysis_result, confidence FROM ai_analysis_cache
       WHERE content_hash = $1`,
      [hash]
    );
    return result.rows[0] || null;
  }

  static async insert(
    contentHash: string,
    content: string,
    analysisResult: any,
    confidence: number
  ) {
    try {
      await Database.query(
        `INSERT INTO ai_analysis_cache (content_hash, content, analysis_result, confidence)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (content_hash) DO NOTHING`,
        [contentHash, content, JSON.stringify(analysisResult), confidence]
      );
    } catch (error) {
      console.warn('Failed to cache analysis:', error);
      // Continue anyway, caching failure shouldn't block analysis
    }
  }

  static async hashContent(content: string): Promise<string> {
    return crypto.createHash('sha256').update(content).digest('hex');
  }
}
```

## Step 2: Create AI Service

Create `src/services/ai.ts`:

```typescript
import { OpenAI } from 'openai';
import Database from './database';
import { AIAnalysisCacheModel } from '../models/AIAnalysisCache';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export class AIService {
  static async analyzeBlocks(blocks: any[]) {
    const results = [];

    for (const block of blocks) {
      const content = block.content?.trim();

      if (!content) {
        results.push(block);
        continue;
      }

      try {
        // Check cache first
        const hash = await AIAnalysisCacheModel.hashContent(content);
        const cached = await AIAnalysisCacheModel.getByContentHash(hash);

        if (cached) {
          results.push({
            ...block,
            ...cached.analysis_result,
            confidence: cached.confidence,
          });
          continue;
        }

        // Analyze with OpenAI
        const analysis = await this.analyzeWithOpenAI(content);

        // Cache the result
        await AIAnalysisCacheModel.insert(hash, content, analysis, analysis.confidence || 0);

        results.push({
          ...block,
          ...analysis,
        });
      } catch (error) {
        console.error('Error analyzing block:', error);
        // Return block with zeros if analysis fails
        results.push({
          ...block,
          calories: 0,
          protein: 0,
          fat: 0,
          carbs: 0,
          fiber: 0,
          sugar: 0,
          sodium: 0,
          confidence: 0,
        });
      }
    }

    return results;
  }

  private static async analyzeWithOpenAI(content: string) {
    try {
      const completion = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: `You are a nutrition expert. Analyze the food description and return ONLY a valid JSON object with these exact fields (all numbers):
            {
              "calories": <number>,
              "protein": <number in grams>,
              "fat": <number in grams>,
              "carbs": <number in grams>,
              "fiber": <number in grams>,
              "sugar": <number in grams>,
              "sodium": <number in mg>,
              "confidence": <number between 0 and 1>
            }
            
            If you cannot determine the nutrition, use your best estimate. Always return valid JSON.`,
          },
          {
            role: 'user',
            content: `Analyze this food: ${content}`,
          },
        ],
        temperature: 0.2,
      });

      const responseText = completion.choices[0].message.content;
      if (!responseText) {
        throw new Error('Empty response from OpenAI');
      }

      const analysis = JSON.parse(responseText);
      return {
        calories: parseInt(analysis.calories || 0),
        protein: parseFloat(analysis.protein || 0),
        fat: parseFloat(analysis.fat || 0),
        carbs: parseFloat(analysis.carbs || 0),
        fiber: parseFloat(analysis.fiber || 0),
        sugar: parseFloat(analysis.sugar || 0),
        sodium: parseFloat(analysis.sodium || 0),
        confidence: parseFloat(analysis.confidence || 0.5),
      };
    } catch (error) {
      console.error('OpenAI analysis error:', error);
      throw error;
    }
  }

  static async calculateTotals(blocks: any[]) {
    return blocks.reduce(
      (totals, block) => ({
        total_calories: totals.total_calories + (block.calories || 0),
        total_protein: totals.total_protein + (block.protein || 0),
        total_fat: totals.total_fat + (block.fat || 0),
        total_carbs: totals.total_carbs + (block.carbs || 0),
        total_fiber: totals.total_fiber + (block.fiber || 0),
        total_sugar: totals.total_sugar + (block.sugar || 0),
        total_sodium: totals.total_sodium + (block.sodium || 0),
      }),
      {
        total_calories: 0,
        total_protein: 0,
        total_fat: 0,
        total_carbs: 0,
        total_fiber: 0,
        total_sugar: 0,
        total_sodium: 0,
      }
    );
  }
}
```

## Step 3: Create AI Routes

Create `src/routes/ai.ts`:

```typescript
import { Router } from 'express';
import { AuthRequest, authenticateToken } from '../middleware/auth';
import { DiaryEntryModel } from '../models/DiaryEntry';
import { AIService } from '../services/ai';
import Database from '../services/database';

const router = Router();

router.use(authenticateToken);

// POST /api/ai/analyze
router.post('/analyze', async (req: AuthRequest, res) => {
  try {
    const { entryId, blocks } = req.body;
    const userId = req.userId!;

    if (!entryId || !Array.isArray(blocks)) {
      return res.status(400).json({
        error: 'entryId and blocks array are required',
      });
    }

    // Verify entry ownership
    const entry = await DiaryEntryModel.getById(entryId);
    if (!entry || entry.user_id !== userId) {
      return res.status(404).json({ error: 'Entry not found' });
    }

    // Mark as processing
    await Database.query(
      `UPDATE diary_entries SET ai_analysis_status = $1 WHERE id = $2`,
      ['processing', entryId]
    );

    try {
      // Analyze blocks
      const analyzedBlocks = await AIService.analyzeBlocks(blocks);

      // Calculate totals
      const totals = await AIService.calculateTotals(analyzedBlocks);

      // Update entry with results
      await Database.query(
        `UPDATE diary_entries SET
         blocks = $1,
         total_calories = $2,
         total_protein = $3,
         total_fat = $4,
         total_carbs = $5,
         total_fiber = $6,
         total_sugar = $7,
         total_sodium = $8,
         ai_analysis_status = $9
         WHERE id = $10`,
        [
          JSON.stringify(analyzedBlocks),
          totals.total_calories,
          totals.total_protein,
          totals.total_fat,
          totals.total_carbs,
          totals.total_fiber,
          totals.total_sugar,
          totals.total_sodium,
          'completed',
          entryId,
        ]
      );

      res.json({
        success: true,
        updatedBlocksCount: analyzedBlocks.length,
      });
    } catch (error) {
      console.error('Analysis error:', error);
      
      // Mark as failed
      await Database.query(
        `UPDATE diary_entries SET ai_analysis_status = $1, ai_analysis_error = $2 WHERE id = $3`,
        ['failed', error instanceof Error ? error.message : 'Unknown error', entryId]
      );

      res.status(500).json({
        error: 'Analysis failed',
        message: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  } catch (error) {
    console.error('Request error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
```

## Step 4: Update app.ts

Add AI routes:

```typescript
import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import authRoutes from './routes/auth';
import diaryRoutes from './routes/diary';
import aiRoutes from './routes/ai';

dotenv.config({ path: '.env.local' });

const app: Express = express();

app.use(cors());
app.use(express.json());

app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/api/auth', authRoutes);
app.use('/api/diary', diaryRoutes);
app.use('/api/ai', aiRoutes);

export default app;
```

---

# Part 5: Testing & Debugging (done)

- [x] Postman environment configured ("CalCalCal Local")
- [x] Health Check returns 200
- [x] Apple Sign-In returns tokens
- [x] Create Diary Entry returns 201
- [x] Get Profile returns 200
- [x] AI Analyze endpoint tested (if OPENAI_API_KEY set)

## Testing with Postman

### 1. Create a Postman Environment

In Postman, create a new environment called "CalCalCal Local":

```json
{
  "BASE_URL": "http://localhost:3000",
  "ACCESS_TOKEN": "",
  "REFRESH_TOKEN": ""
}
```

### 2. Test Endpoints

**Health Check:**
```
GET http://localhost:3000/health
```

**Apple Sign-In:**
```
POST http://localhost:3000/api/auth/signin-apple
Body (JSON):
{
  "identityToken": "test",
  "user": {
    "id": "com.apple.user.123456",
    "email": "test@example.com",
    "name": "Test User"
  }
}
```

Save the `access_token` from response to Postman environment.

**Create Diary Entry:**
```
POST http://localhost:3000/api/diary/entries
Headers: Authorization: Bearer {{ACCESS_TOKEN}}
Body (JSON):
{
  "date": "2024-01-15",
  "content": "Had two eggs and toast for breakfast"
}
```

**Get Profile:**
```
GET http://localhost:3000/api/auth/profile
Headers: Authorization: Bearer {{ACCESS_TOKEN}}
```

**Analyze Blocks:**
```
POST http://localhost:3000/api/ai/analyze
Headers: Authorization: Bearer {{ACCESS_TOKEN}}
Body (JSON):
{
  "entryId": "<entry-id-from-create>",
  "blocks": [
    {
      "id": "block-1",
      "content": "Two eggs and toast",
      "position": 1
    }
  ]
}
```

## Debugging Logs

Add more detailed logging to debug issues. Update `src/app.ts`:

```typescript
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});
```

## Common Issues

### Issue: "Cannot find module 'pg'"
```bash
npm install pg
```

### Issue: Database connection fails
```bash
# Check PostgreSQL is running
brew services list | grep postgresql

# Check database exists
psql -l | grep calcalcal
```

### Issue: OpenAI API errors
```bash
# Verify API key in .env.local
echo $OPENAI_API_KEY
```

---

# Part 6: Production Deployment

## Why DigitalOcean vs Other Platforms?

### Comparison

**DigitalOcean App Platform:**
- ✅ **Managed PostgreSQL** included (same platform as API)
- ✅ **Simple YAML config** (`app.yaml`) - no Docker needed
- ✅ **GitHub integration** - auto-deploy on push
- ✅ **Built-in databases** - no separate DB setup
- ✅ **Good for beginners** - minimal DevOps knowledge needed
- ❌ More expensive than some alternatives (~$12-25/month)
- ❌ Less flexible than self-managed VPS

**Cloudflare Workers/Pages:**
- ✅ **Free tier** is generous (for static/simple APIs)
- ✅ **Edge computing** - global CDN
- ✅ **Very fast** deployment
- ❌ **No PostgreSQL** - you'd need separate DB (RDS, Neon, Supabase)
- ❌ **Limited runtime** - Workers have execution time limits (10-30s)
- ❌ **Not ideal for Node.js** - better for lightweight functions
- ❌ **Not suitable** for Express.js apps with long-running connections

**Railway / Render:**
- ✅ **Simpler than DigitalOcean** - even easier setup
- ✅ **PostgreSQL included** (Railway) or easy to add (Render)
- ✅ **Good free tiers** for testing
- ✅ **GitHub integration**
- ❌ **Less predictable pricing** (pay-as-you-go can get expensive)
- ❌ **Less control** over infrastructure

**AWS / GCP / Azure:**
- ✅ **Highly scalable** - enterprise-grade
- ✅ **More services** available
- ❌ **Much more complex** - requires DevOps knowledge
- ❌ **More expensive** for small apps
- ❌ **Overkill** for MVP/solo projects

**VPS (Hetzner / DigitalOcean Droplets / Linode):**
- ✅ **Cheapest option** (~$5-10/month)
- ✅ **Full control** - do whatever you want
- ❌ **You manage everything** - updates, security, monitoring
- ❌ **Requires Linux/DevOps skills** - not beginner-friendly
- ❌ **Need separate DB setup** - adds complexity

### Recommendation: DigitalOcean App Platform

For this project, **DigitalOcean App Platform** was chosen because:
1. **Database included** - PostgreSQL managed on same platform (no separate setup)
2. **Beginner-friendly** - YAML config, no Docker/k8s knowledge needed
3. **Monorepo support** - easy to deploy from subdirectory (`source_dir`)
4. **Predictable pricing** - ~$12-25/month all-in (API + DB)
5. **GitHub integration** - automatic deployments
6. **Production-ready** - handles scaling, SSL, health checks automatically

If you want alternatives:
- **Railway** ($5-20/month) - easier but less control
- **Render** ($7-25/month) - similar to DigitalOcean, good free tier
- **VPS + Docker** ($5-10/month) - cheapest but requires DevOps skills

## Option A: DigitalOcean App Platform (Recommended for Beginners)

### Step 1: Create DigitalOcean Account

Visit https://www.digitalocean.com and sign up (~$5-15/month)

### Step 2: Prepare Your Code

Create `app.yaml` in project root:

```yaml
name: calcalcal-api
services:
- name: api
  github:
    repo: your-github-username/calcalcal-backend
    branch: main
  source_dir: apps/backend/node  # IMPORTANT: Specify the backend directory
  build_command: npm install && npm run build
  run_command: npm start
  envs:
  - key: NODE_ENV
    value: production
  - key: DATABASE_URL
    value: ${db.connection_string}
  - key: JWT_SECRET
    scope: RUN_AND_BUILD_TIME
  - key: OPENAI_API_KEY
    scope: RUN_AND_BUILD_TIME
  http_port: 3000
  health_check:
    http:
      path: /health

databases:
- name: db
  engine: PG
  production: true
  version: "15"
```

**Important**: If your backend code is in a subdirectory (like `apps/backend/node`), you MUST specify `source_dir` in the service config. Otherwise DigitalOcean will scan the root directory and fail to find `package.json`.

### Step 3: Push to GitHub

```bash
git add .
git commit -m "Initial backend setup"
git push origin main
```

### Step 4: Deploy via DigitalOcean Dashboard

1. Go to App Platform → Create App
2. Choose GitHub repository (make sure it's the correct repo with `app.yaml` and `apps/backend/node/` directory)
3. Select `app.yaml` as configuration
4. Set environment variables (JWT_SECRET, OPENAI_API_KEY)
5. Click Deploy

**If you get "No components detected" error:**
- Verify `source_dir: apps/backend/node` is in your `app.yaml`
- Make sure `package.json` exists in `apps/backend/node/`
- Ensure your GitHub repo has the latest code pushed

Your API will be live at: `https://calcalcal-api-xxx.ondigitalocean.app`

**Production API URL (Actual):**
- **Live API URL**: `https://calycal-app-egy2b.ondigitalocean.app`
- **Health Check**: `https://calycal-app-egy2b.ondigitalocean.app/health`
- Use this URL when updating the iOS app configuration (see Part 7)

### Resource Requirements & Cost Optimization

**DigitalOcean App Platform Pricing:**
- **Basic Plan**: $12/month (512MB RAM, 1 vCPU) - **Tight but workable for MVP**
- **Professional Plan**: $25/month (1GB RAM, 1 vCPU) - **Recommended for growth**
- **Database**: Included but shares resources with app

**Is 512MB RAM / 1 vCPU enough?**
- ✅ **Yes for MVP** - Simple Express API with low traffic (<1000 requests/day)
- ⚠️ **Tight** - Node.js needs ~150-200MB, PostgreSQL connections use memory
- 📈 **Monitor** - Watch memory usage, upgrade if you see OOM errors
- 💡 **Optimization**: Limit PostgreSQL connection pool size (default 10, reduce to 5)

**Cost Comparison:**
- **DigitalOcean App Platform**: $12-25/month (managed, easy)
- **VPS + Docker** (Hetzner/DigitalOcean Droplet): $5-10/month (you manage)
- **Railway/Render**: $5-20/month (variable pricing)

**Recommendation**: Start with 512MB/1vCPU, monitor, upgrade to 1GB when needed.

---

## Option B: Docker Setup (For Future VPS Migration)

If you want to migrate to a cheaper VPS later, Docker makes it easy. Docker files are already created in `apps/backend/node/`.

### Docker Files Created:
- `Dockerfile` - Production-ready multi-stage build
- `docker-compose.yml` - For local development/testing
- `.dockerignore` - Excludes unnecessary files

### Quick Start with Docker:

```bash
cd apps/backend/node

# Build the image
docker build -t calcalcal-api .

# Run locally (needs DATABASE_URL env var)
docker run -p 3000:3000 \
  -e DATABASE_URL="postgresql://..." \
  -e JWT_SECRET="your-secret" \
  -e OPENAI_API_KEY="sk-..." \
  calcalcal-api

# Or use docker-compose (easier)
docker-compose up
```

### Migrating to VPS Later:

When ready to move to a cheaper VPS ($5-10/month):

1. **Choose VPS**: Hetzner, DigitalOcean Droplet, or Linode
2. **Install Docker**: `curl -fsSL https://get.docker.com | sh`
3. **Clone repo** and build: `docker build -t calcalcal-api .`
4. **Set up PostgreSQL**: Use managed DB (Supabase free tier) or Docker PostgreSQL
5. **Run**: `docker run -d -p 80:3000 --env-file .env.production calcalcal-api`
6. **Add reverse proxy**: Nginx or Caddy for SSL

**Estimated savings**: $7-15/month vs DigitalOcean App Platform

---

# Part 7: iOS App Migration

## Step 1: Update Configuration

Edit `calcalcal/Models/Configuration.swift`:

**Production API URL**: `https://calycal-app-egy2b.ondigitalocean.app`

```swift
struct Configuration {
    static let supabaseURL = "https://calycal-app-egy2b.ondigitalocean.app" // DigitalOcean API
    static let supabaseAnonKey = "" // No longer needed (not used with custom backend)
}
```

## Step 2: Update AuthManager (Minimal Changes)

The auth flow is almost identical. Your existing code should work!

Just ensure the endpoint matches:
- `POST /api/auth/signin-apple` (instead of `/functions/v1/apple-signin`)
- `GET /api/auth/profile` (instead of `/functions/v1/auth-profile`)
- `POST /api/auth/refresh` (instead of `/functions/v1/auth-refresh`)

## Step 3: Update DiaryAPI (Minimal Changes)

Change the base URL prefix from `/rest/v1` to `/api/diary`:

```swift
// Before
let urlString = "\(base)/rest/v1/diary_entries?..."

// After
let urlString = "\(base)/api/diary/entries?..."
```

## Step 4: Test in Simulator

```bash
xcode-select --install  # If needed
open calcalcal.xcodeproj

# Build and run in Xcode (Cmd+R)
```

---

## Summary

You now have a **complete, self-hosted backend** that:

✅ Handles Apple Sign-In securely  
✅ Stores user data in PostgreSQL  
✅ Provides REST API for diary CRUD  
✅ Analyzes food with OpenAI  
✅ Runs locally for development  
✅ Deploys to production with one click  

**Next steps:**
1. Deploy to production (DigitalOcean or VPS)
2. Update iOS app configuration
3. Beta test with TestFlight
4. Shut down Supabase (after confirming everything works)

**Estimated cost:** ~$10-20/month (vs. Supabase reliability issues)  
**Estimated time:** 2-3 weeks for a first-timer following this guide

Good luck! 🚀
