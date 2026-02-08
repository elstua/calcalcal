# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CalCalCal is an iOS calorie tracker where users log food in natural language. LLMs analyze the text (and images) to calculate nutrition per paragraph. The app uses a notes-like interface: text on the left, calories on the right, with each paragraph tracked independently.

## Build & Run Commands

### iOS App
```bash
# Build (Debug - local backend)
xcodebuild -scheme Calycal -project Calycal.xcodeproj -configuration Debug build

# Build (Release - production)
xcodebuild -scheme Calycal -project Calycal.xcodeproj -configuration Release build

# Run tests
xcodebuild -scheme Calycal -project Calycal.xcodeproj test
```

### Backend (Node.js/TypeScript)
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

## Architecture

### iOS App (`calcalcal/`)
- **SwiftUI + UIKit hybrid**, MVVM with `ObservableObject`
- **Global state**: `AppState` (auth, onboarding, streaks) + `AuthManager` (Apple/Google/temp accounts)
- **Networking**: `DiaryAPI` struct for all backend calls, JWT Bearer token auth
- **Config**: `Configuration.swift` reads API URLs from Info.plist (set via xcconfig files)
- **Design system**: `DesignSystem/` — use `DSColors`, `DSSpacing`, `DSTypography`, `DSCard`, `DSButton` tokens for all new UI

### EditorV2 — TextKit 2 Block Editor (`calcalcal/EditorV2/`)
The core text editor is complex. Key constraints to understand:

1. **Do NOT subclass `NSTextContentStorage`** — causes `NSRangeException` crashes. Use the default provided by `UITextView`.
2. **Do NOT use `NSTextAttachment` for images** — causes caret to grow to attachment height. Instead, use invisible marker characters (`\u{FFFC}`) with `UIHostingController` overlays.
3. **Do NOT use `renderingAttributesValidator` for paragraph spacing** — causes caret/selection mismatch. Bake spacing into `NSAttributedString` via `typingAttributes`.
4. **Clamp all ranges** before any storage access.
5. **Never mutate attributes inside TextKit callbacks** — only observe and rebuild the model.

Object graph: `BlockEditorTextView` → `BlockDocumentController` (observes NSTextStorage, rebuilds `BlockDocument`) → `BlockTextLayoutController` (custom layout fragments per block kind).

### Backend (`apps/backend/node/src/`)
- **Express + TypeScript + PostgreSQL** with manual SQL migrations (`migrations/*.sql`)
- **Routes**: `auth.ts`, `diary.ts`, `ai.ts`, `storage.ts`, `streaks.ts` under `/api/*`
- **AI service**: Provider abstraction over OpenAI and Gemini (`services/ai/`)
- **Image storage**: Cloudflare R2 (`services/storage/r2.ts`)
- **Auth middleware**: `authenticateToken` — extend `AuthRequest` for `userId` access

## Environments

| Environment | Build Config | API URL |
|-------------|-------------|---------|
| Local Dev | Debug | `http://localhost:3000` (Docker) |
| Staging | Staging | Configurable |
| Production | Release | `https://api.calcalcal.app` |

xcconfig files in `xcconfigs/` define URLs. Note: `//` is a comment in xcconfig, so URLs use single slashes (e.g., `http:/localhost:3000`) — `Configuration.swift` fixes them at runtime.

Switch environments: Xcode → Product → Scheme → Edit Scheme → Run → Build Configuration.

## Code Style

### Swift
- MVVM, `ObservableObject` for state, `async/await` for networking
- Use design system tokens (`DSColors`, `DSSpacing`, `DSTypography`, `DSCard`, `DSButton`) for all UI
- `guard`/`if-let` for optional unwrapping
- Linter may show false "no such module UIKit" errors — these are safe to ignore

### TypeScript (Backend)
- Strict TypeScript, interfaces for all request/response shapes
- Parameterized SQL queries (never interpolate user input)
- `try/catch` on all async route handlers, return structured JSON errors with status codes
- Group imports by type: express, services, models, types
