# Agent Guidelines for CalCalCal

## Project Structure
- **iOS App**: SwiftUI/UIKit hybrid in `calcalcal/` (Xcode project)
- **Backend**: Node.js/TypeScript/Express in `apps/backend/node/`
- CalCalCal is an iOS calorie tracker that uses LLMs to analyze food entries in natural language

## Backend Structure (`apps/backend/node/src/`)
```
middleware/auth.ts        # JWT authentication middleware (authenticateToken)
models/                   # Database models with static methods
  ├── User.ts            # User CRUD operations
  ├── DiaryEntry.ts      # Diary entry & blocks management
  ├── RefreshToken.ts    # Token refresh logic
  └── AIAnalysisCache.ts # AI response caching
routes/                   # Express route handlers
  ├── auth.ts            # /api/auth/* - login, signup, refresh, Google OAuth
  ├── diary.ts           # /api/diary/* - CRUD for diary entries
  ├── ai.ts              # /api/ai/* - analyze & analyze-block endpoints
  └── storage.ts         # /api/storage/* - image upload/retrieval (R2)
services/
  ├── auth.ts            # JWT token generation/verification
  ├── database.ts        # PostgreSQL connection pool
  ├── calorieCalculator.ts # Legacy service (deprecated)
  ├── ai/                # AI provider abstraction
  │   ├── service.ts     # Main AI service coordinator
  │   ├── providers/     # OpenAI & Gemini implementations
  │   └── prompts/       # Prompt templates for nutrition analysis
  └── storage/r2.ts      # Cloudflare R2 image storage
migrations/               # Sequential SQL migrations (001_init.sql, etc.)
```

## Build & Test Commands
- **iOS Build**: `xcodebuild -scheme Calycal -project Calycal.xcodeproj build`
- **iOS Test**: `xcodebuild -scheme Calycal -project Calycal.xcodeproj test`
- **Backend Build**: `cd apps/backend/node && npm run build`
- **Backend Test**: `cd apps/backend/node && npm test` (tests in `src/test/**/*.test.ts`)
- **Backend Dev**: `cd apps/backend/node && npm run dev`
- **Backend Migrate**: `cd apps/backend/node && npm run migrate` (run SQL migrations)

## Code Style - TypeScript/Node Backend
- **Imports**: Group by type (express, services, models, types), use named imports
- **Types**: Strict TypeScript (`strict: true`), define interfaces for all request/response shapes
- **Error Handling**: Always try/catch async routes, return structured JSON errors with status codes
- **Auth**: Use `authenticateToken` middleware, extend `AuthRequest` for `userId` access
- **Naming**: camelCase for variables/functions, PascalCase for types/interfaces
- **Database**: PostgreSQL with manual migrations in `migrations/*.sql`, use parameterized queries

## Code Style - Swift/iOS
- **Imports**: Foundation, SwiftUI, UIKit (note: linter may show false UIKit errors - ignore them)
- **Naming**: camelCase for properties/functions, PascalCase for types/structs
- **Types**: Use explicit types for clarity, optionals with guard/if-let unwrapping
- **Error Handling**: Use `throws` for async operations, structured error types
- **Architecture**: MVVM pattern, ObservableObject for state, async/await for networking
- **API**: JWT Bearer token auth in headers, use `DiaryAPI` struct for all backend calls
