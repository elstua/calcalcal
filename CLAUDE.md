# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CalCalCal is an iOS calorie tracker where users log food in natural language. LLMs analyze the text (and images) to calculate nutrition per paragraph. The app uses a notes-like interface: text on the left, calories on the right, with each paragraph tracked independently.

## Repository Structure

```
calcalcal/              # iOS app (SwiftUI + UIKit hybrid)
  CLAUDE.md             # Detailed iOS development guide
apps/backend/node/      # Backend API (Express + TypeScript + PostgreSQL)
  CLAUDE.md             # Detailed backend development guide
xcconfigs/              # Xcode build configurations (Debug/Release/Staging)
scripts/                # Dev setup scripts
Docs/                   # Historical implementation docs
```

## Build & Run Commands

### iOS App
```bash
xcodebuild -scheme Calycal -project Calycal.xcodeproj -configuration Debug build    # Local backend
xcodebuild -scheme Calycal -project Calycal.xcodeproj -configuration Release build  # Production
xcodebuild -scheme Calycal -project Calycal.xcodeproj test
```

### Backend
```bash
cd apps/backend/node
npm run build          # Build
npm test               # Run tests (src/test/**/*.test.ts)
npm run dev            # Dev server with hot reload

# Local environment (Docker)
docker-compose -f docker-compose.dev.yml up -d   # Start PostgreSQL + API
npm run migrate:dev                                # Run migrations
docker-compose -f docker-compose.dev.yml logs -f api  # View logs
docker-compose -f docker-compose.dev.yml down     # Stop
docker-compose -f docker-compose.dev.yml down -v  # Stop + delete data
```

## Environments

| Environment | Build Config | API URL |
|-------------|-------------|---------|
| Local Dev | Debug | `http://localhost:3000` (Docker) |
| Staging | Staging | Configurable |
| Production | Release | `https://api.calcalcal.app` |

xcconfig files in `xcconfigs/` define URLs. Note: `//` is a comment in xcconfig, so URLs use single slashes (e.g., `http:/localhost:3000`) — `Configuration.swift` fixes them at runtime.

Switch environments: Xcode → Product → Scheme → Edit Scheme → Run → Build Configuration.

## Architecture at a Glance

- **iOS**: SwiftUI + UIKit hybrid, MVVM, `ObservableObject` for state, `async/await` networking
- **Backend**: Express + TypeScript + PostgreSQL, JWT auth, AI provider abstraction (OpenAI/Gemini), Cloudflare R2 storage
- **Global state**: `AppState` (auth, onboarding, streaks) + `AuthManager` (Apple/Google/temp accounts)
- **Networking**: `DiaryAPI` struct for all backend calls, JWT Bearer token auth
- **Design system**: `DesignSystem/` — tokens: `DSColors`, `DSSpacing`, `DSTypography`, `DSCard`, `DSButton`

See `calcalcal/CLAUDE.md` and `apps/backend/node/CLAUDE.md` for detailed architecture guides.

## Code Style

### Swift
- MVVM, `ObservableObject` for state, `async/await` for networking
- Use design system tokens (`DSColors`, `DSSpacing`, `DSTypography`, `DSCard`, `DSButton`) for all UI
- `guard`/`if-let` for optional unwrapping
- Linter may show false "no such module UIKit" errors — safe to ignore

### TypeScript (Backend)
- Strict TypeScript, interfaces for all request/response shapes
- Parameterized SQL queries (never interpolate user input)
- `try/catch` on all async route handlers, return structured JSON errors with status codes
- Group imports by type: express, services, models, types
