# Local Development Setup for CalCalCal

This guide explains how to set up a complete local development environment for CalCalCal, allowing you to develop and test both the iOS app and backend locally without deploying to production.

## Overview

### The Problem
Previously, the only way to test backend changes was to:
1. Deploy to VPS via `deploy.sh`
2. Wait for build and health checks
3. Test on production environment

### The Solution
We've set up **multiple environments**:

| Environment | iOS Build | API URL | Backend |
|-------------|-----------|---------|---------|
| **Local Dev** | Debug | `http://localhost:3000` | Docker on your machine |
| **Staging** | Staging | (optional staging server) | Separate VPS |
| **Production** | Release | `https://api.calcalcal.app` | Production VPS |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         YOUR MAC                                 │
│  ┌─────────────────────┐      ┌──────────────────────────┐     │
│  │   iOS Simulator     │      │   Docker Desktop         │     │
│  │   (Debug Build)     │──────▶│   ┌──────────────────┐   │     │
│  │                     │      │   │  Node.js API     │   │     │
│  │  API_URL: localhost │      │   │  Port: 3000      │   │     │
│  │                     │      │   └──────────────────┘   │     │
│  └─────────────────────┘      │   ┌──────────────────┐   │     │
│                               │   │  PostgreSQL      │   │     │
│                               │   │  Port: 5432      │   │     │
│                               │   └──────────────────┘   │     │
│                               └──────────────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ (deploy via deploy.sh)
                    ┌─────────────────────┐
                    │   Production VPS    │
                    │  api.calcalcal.app  │
                    └─────────────────────┘
```

## Quick Start

### 1. Start the Local Backend

```bash
cd apps/backend/node

# Start PostgreSQL and API server
docker-compose -f docker-compose.dev.yml up -d

# Run database migrations
npm run migrate:dev

# Check logs
docker-compose -f docker-compose.dev.yml logs -f api
```

The API will be available at: `http://localhost:3000`

### 2. Configure Xcode

1. **Open** `Calycal.xcodeproj` in Xcode

2. **Select the Project** (blue icon) → **Info** tab

3. **Configure Build Configurations:**
   
   | Configuration | xcconfig File |
   |---------------|---------------|
   | Debug | `xcconfigs/Debug.xcconfig` |
   | Release | `xcconfigs/Release.xcconfig` |

   To set this:
   - Click on each configuration
   - Select the corresponding xcconfig from the dropdown

4. **Verify Configuration:**
   - Select the target → **Build Settings**
   - Search for "API_URL"
   - Debug should show: `http://localhost:3000`
   - Release should show: `https://api.calcalcal.app`

### 3. Build and Run

- Select **Debug** scheme
- Build and run on simulator
- The app will connect to your local backend

## Detailed Configuration

### Backend Development (`docker-compose.dev.yml`)

The development Docker setup includes:

| Service | Port | Description |
|---------|------|-------------|
| `api` | 3000 | Node.js API server (with hot reload) |
| `postgres` | 5432 | PostgreSQL database |

**Features:**
- Source code mounted for hot reload
- Separate database volume (`postgres_dev_data`)
- Health checks for dependencies

**Useful Commands:**

```bash
# Start services
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f api

# Stop services
docker-compose -f docker-compose.dev.yml down

# Reset database (delete all data)
docker-compose -f docker-compose.dev.yml down -v

# Run migrations
npm run migrate:dev

# Seed test data (if you have seed scripts)
# npm run seed:dev
```

### iOS Build Configurations

#### Debug Configuration (`xcconfigs/Debug.xcconfig`)

```
API_URL = http://localhost:3000
MEDIA_URL = http://localhost:3000
```

**Characteristics:**
- No code optimization
- Debug symbols enabled
- HTTP allowed (for localhost)
- Testability enabled

#### Release Configuration (`xcconfigs/Release.xcconfig`)

```
API_URL = https://api.calcalcal.app
MEDIA_URL = https://media.calcalcal.app
```

**Characteristics:**
- Full optimization
- No debug assertions
- HTTPS required
- Smaller binary size

### Configuration.swift

The `Configuration.swift` file reads URLs from Info.plist and fixes the single-slash format:

```swift
// In DEBUG builds:
Configuration.apiURL     // "http://localhost:3000"
Configuration.mediaBaseURL // "http://localhost:3000"

// In RELEASE builds:
Configuration.apiURL     // "https://api.calcalcal.app"
Configuration.mediaBaseURL // "https://media.calcalcal.app"
```

**Note about xcconfig URL format:** Since `//` starts a comment in xcconfig files, URLs are defined with single slashes:
```xcconfig
// xcconfigs/Debug.xcconfig
API_URL = http:/localhost:3000   // Will be fixed to http:// in code
```

To change the URLs, edit the appropriate xcconfig file.

**Helper Properties:**

```swift
Configuration.isLocalDevelopment  // true for localhost/192.168.x.x
Configuration.isProduction        // true for api.calcalcal.app
Configuration.environmentName     // "Debug (Local)", "Staging", or "Release (Production)"
```

## Testing on Physical Devices

When testing on a physical iPhone, `localhost` won't work (it refers to the phone, not your Mac).

### Option 1: Use Your Mac's IP Address

1. Find your Mac's local IP:
   ```bash
   ipconfig getifaddr en0
   # or
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```

2. Update `xcconfigs/Debug.xcconfig`:
   ```
   API_URL = http://192.168.1.X:3000
   ```

3. Update `calcalcal/Info.plist` to allow your local network:
   ```xml
   <key>192.168.1.0</key>
   <dict>
       <key>NSExceptionAllowsInsecureHTTPLoads</key>
       <true/>
       <key>NSIncludesSubdomains</key>
       <true/>
   </dict>
   ```

4. Ensure your Mac's firewall allows port 3000

### Option 2: Use ngrok (Public URL)

```bash
# Install ngrok
brew install ngrok

# Create tunnel
ngrok http 3000

# Use the https URL in your xcconfig
# API_URL = https://xxxx.ngrok-free.app
```

## Switching Environments

### In Xcode

1. **Edit Scheme** → **Run** → **Build Configuration**
2. Select **Debug** (local) or **Release** (production)
3. Build and run

### Using Command Line

```bash
# Build debug (local backend)
xcodebuild -scheme Calycal -configuration Debug build

# Build release (production)
xcodebuild -scheme Calycal -configuration Release build
```

## Environment-Specific Code

Use Swift compiler flags for environment-specific code:

```swift
#if DEBUG
    // Only in debug builds
    print("Debug: Using local server")
#endif

#if STAGING
    // Only in staging builds
#endif
```

## Troubleshooting

### "Cannot connect to server" on Simulator

1. Verify backend is running:
   ```bash
   curl http://localhost:3000/health
   ```

2. Check Info.plist has correct API_URL

3. Check App Transport Security settings in Info.plist

### Database Connection Issues

```bash
# Reset everything
cd apps/backend/node
docker-compose -f docker-compose.dev.yml down -v
docker-compose -f docker-compose.dev.yml up -d
npm run migrate:dev
```

### Xcode Not Reading xcconfig

1. Check file is selected in project settings
2. Clean build folder: **Cmd+Shift+K**
3. Delete derived data
4. Restart Xcode

### API_URL showing as `${API_URL}` in app

This means the variable wasn't expanded. Check:
1. xcconfig file is assigned to configuration
2. Info.plist key is `$(API_URL)` not hardcoded value
3. Build settings show resolved value

## Advanced: Adding a Staging Environment

1. **Duplicate Release configuration** in Xcode
2. **Name it "Staging"**
3. **Assign** `xcconfigs/Staging.xcconfig`
4. **Deploy staging backend** to separate VPS
5. **Update** `Staging.xcconfig` with staging URLs

## Security Notes

- Never commit `.env.production` or real API keys
- `.env.local` is gitignored for local development
- Debug builds allow HTTP only to localhost/private IPs
- Release builds require HTTPS

## Summary Commands

```bash
# Setup
./scripts/setup-local-dev.sh

# Start local backend
cd apps/backend/node
docker-compose -f docker-compose.dev.yml up -d
npm run migrate:dev

# Build iOS app (Debug - local backend)
xcodebuild -scheme Calycal -configuration Debug build

# Build iOS app (Release - production)
xcodebuild -scheme Calycal -configuration Release build
```
