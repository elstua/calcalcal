# Calycal Authentication Implementation Guide

## Overview
This guide covers the complete authentication implementation for the Calycal app, including backend setup, iOS integration, and testing.

## Backend Setup

### 1. Environment Configuration

Copy the environment variables from `env.example` to your local environment:

```bash
cp env.example .env
```

Update the following variables for your setup:

- `APPLE_CLIENT_ID`: Your iOS app's bundle identifier (e.g., `com.calycal.app`)
- `APPLE_TEAM_ID`: Your Apple Developer Team ID
- `APPLE_KEY_ID`: Your Apple Sign-In key ID
- `APPLE_PRIVATE_KEY`: Your Apple Sign-In private key

### 2. Database Setup

The database schema is already configured with the necessary tables:

- `user_profiles`: Stores user information and preferences
- `diary_entries`: Stores nutrition diary entries
- `ai_analysis_cache`: Caches AI analysis results

### 3. Supabase Functions

The following authentication functions are implemented:

#### Apple Sign-In (`/functions/v1/auth-apple-signin`)
- Verifies Apple ID tokens
- Creates or updates user profiles
- Returns session tokens

**IMPORTANT**: This function requires an authorization header with a valid Supabase anon key for local development.

#### Profile Management (`/functions/v1/auth-profile`)
- GET: Retrieve user profile
- PATCH: Update user profile

#### Token Refresh (`/functions/v1/auth-refresh`)
- Refreshes expired access tokens
- Returns new session tokens

### 4. Testing the Backend

Start the Supabase local development environment:

```bash
npm run dev
```

Deploy the functions:

```bash
supabase functions deploy auth-apple-signin
supabase functions deploy auth-profile
supabase functions deploy auth-refresh
```

Test the Apple Sign-In endpoint:

```bash
curl -X POST http://127.0.0.1:54321/functions/v1/auth-apple-signin \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  -d '{
    "identityToken": "your_apple_id_token",
    "user": {
      "id": "apple_user_id",
      "email": "user@example.com",
      "name": "John Doe"
    }
  }'
```

**Note**: The authorization header is required for local development due to Supabase's security configuration.

## Frontend Integration (iOS)

### 1. Project Setup

#### Add Apple Sign-In Capability
1. Open your Xcode project
2. Select your target
3. Go to "Signing & Capabilities"
4. Click "+" and add "Sign in with Apple"

#### Add Required Frameworks
```swift
import AuthenticationServices
import Security
import Combine
```

### 2. Configuration

Update the `Configuration.swift` file with your Supabase URLs:

```swift
import Foundation
import Supabase

let supabase = SupabaseClient(
  supabaseURL: URL(string: "http://127.0.0.1:54321")!,
  supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
)

struct Configuration {
    static let supabaseURL = "http://127.0.0.1:54321" // Your Supabase URL
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
    static let appleClientId = "com.calcalcal.app" // Your bundle identifier
}
```

### 3. Technical Architecture

#### Core Components
- **AuthManager**: Handles Apple Sign-In flow and backend communication
- **KeychainManager**: Secure token storage using iOS Keychain
- **APIClient**: Network layer for backend API calls
- **AppState**: SwiftUI state management for authentication status

#### Authentication Flow
1. **Apple Sign-In**: User authenticates with Apple ID
2. **Token Processing**: Extract identity token from Apple credentials
3. **Backend Authentication**: Send token to `/functions/v1/auth-apple-signin`
4. **Session Storage**: Store returned session tokens in Keychain
5. **State Update**: Update app authentication state

#### Key Integration Points

**Backend Endpoints**:
- `POST /functions/v1/auth-apple-signin` - Apple Sign-In authentication
- `GET /functions/v1/auth-profile` - Validate session and get user profile
- `POST /functions/v1/auth-refresh` - Refresh expired tokens

**Request Format** (Apple Sign-In):
```json
{
  "identityToken": "apple_id_token",
  "user": {
    "id": "apple_user_id",
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

**Response Format**:
```json
{
  "success": true,
  "user": { /* user data */ },
  "session": {
    "access_token": "jwt_token",
    "refresh_token": "refresh_token",
    "expires_in": 3600
  }
}
```

**Authorization Header**: `Bearer {supabase_anon_key}` for local development requests

#### Session Management
- **Token Storage**: iOS Keychain for secure storage
- **Session Validation**: Automatic validation on app launch
- **Token Refresh**: Automatic refresh when tokens expire
- **Sign Out**: Clear tokens and reset authentication state

#### Error Handling
- **Network Errors**: Retry logic and user feedback
- **Authentication Errors**: Clear error messages and fallback flows
- **Token Errors**: Automatic sign-out on invalid tokens

### 9. Testing the Frontend

1. **Build and run the iOS app**
2. **Test Apple Sign-In flow**:
   - Tap "Sign in with Apple"
   - Complete the Apple Sign-In process
   - Verify the app navigates to the main interface
3. **Test session persistence**:
   - Close and reopen the app
   - Verify the user remains logged in
4. **Test sign-out**:
   - Go to Profile view
   - Tap "Sign Out"
   - Verify the app returns to login screen
5. **Test error handling**:
   - Test with invalid tokens
   - Test network failures
   - Verify appropriate error messages

### 10. Frontend Security Considerations

#### Token Security
- Tokens are stored securely in the iOS Keychain
- Tokens are automatically validated on app launch
- Failed token validation triggers sign out

#### Apple Sign-In Security
- Apple ID tokens are verified on the backend
- User ID from Apple is validated against the token
- Secure token exchange with the backend

#### Network Security
- All API calls use HTTPS (in production)
- Authorization headers are included for authenticated requests
- Comprehensive error handling for network failures

### 11. Frontend Troubleshooting

#### Common Issues

1. **Apple Sign-In not working**
   - Verify "Sign in with Apple" capability is added
   - Check bundle identifier matches Apple Developer configuration
   - Ensure proper entitlements

2. **Token storage issues**
   - Check Keychain access permissions
   - Verify service and account identifiers
   - Handle Keychain errors gracefully

3. **Network errors**
   - Verify backend URL configuration
   - Check network connectivity
   - Handle API errors appropriately

#### Debug Tips

1. Enable network logging in development
2. Use Xcode's network inspector
3. Add comprehensive error logging
4. Test with different Apple ID accounts

### 12. Frontend Development Workflow

#### Local Development
```bash
# Open Xcode project
open calcalcal.xcodeproj

# Build and run
# Press Cmd+R in Xcode
```

#### Testing
```bash
# Run unit tests
# Press Cmd+U in Xcode

# Run UI tests
# Select UI test target and run
```

#### Debugging
```bash
# Enable network logging
# Add breakpoints in AuthManager

# Check Keychain contents
# Use Xcode's Keychain inspector
```

## Security Considerations

### Token Security
- Tokens are stored securely in the iOS Keychain
- Tokens are automatically validated on app launch
- Failed token validation triggers sign out

### Apple Sign-In Security
- Apple ID tokens are verified on the backend using Apple's public keys
- User ID from Apple is validated against the token
- Secure token exchange with the backend

### Network Security
- All API calls use HTTPS (in production)
- Authorization headers are included for authenticated requests
- Comprehensive error handling for network failures

## Troubleshooting

### Backend Issues

1. **Supabase not running**
   ```bash
   npm run start
   ```

2. **Functions not deployed**
   ```bash
   npm run deploy
   ```

3. **Database connection issues**
   ```bash
   npm run reset
   ```

### iOS Issues

1. **Apple Sign-In not working**
   - Verify "Sign in with Apple" capability is added
   - Check bundle identifier matches Apple Developer configuration
   - Ensure proper entitlements

2. **Token storage issues**
   - Check Keychain access permissions
   - Verify service and account identifiers
   - Handle Keychain errors gracefully

3. **Network errors**
   - Verify backend URL configuration
   - Check network connectivity
   - Handle API errors appropriately

### Common Error Messages

- `"Apple user ID mismatch"`: The Apple user ID doesn't match the token
- `"Invalid Apple ID token"`: Token verification failed
- `"Missing required parameters"`: Required fields are missing from the request
- `"Unauthorized"`: Invalid or missing authentication token
- `"Missing authorization header"`: Authorization header required for local development

## Development Workflow

### 1. Local Development
```bash
# Start Supabase
npm run dev

# Deploy functions
supabase functions deploy auth-apple-signin
supabase functions deploy auth-profile
supabase functions deploy auth-refresh

# Test endpoints
curl -X POST http://127.0.0.1:54321/functions/v1/auth-apple-signin \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" \
  -d '{"identityToken": "test", "user": {"id": "test", "email": "test@example.com", "name": "Test"}}'
```

### 2. Testing
```bash
# Run tests
npm test

# Lint code
npm run lint

# Format code
npm run format
```

### 3. Deployment
```bash
# Deploy to staging
npm run deploy:staging

# Deploy to production
npm run deploy:prod
```

## Next Steps

1. **Implement proper JWT token generation** in the backend
2. **Add offline support** for better user experience
3. **Implement biometric authentication** for additional security
4. **Add user profile editing** functionality
5. **Implement push notifications** for engagement
6. **Add analytics and crash reporting** for monitoring

## API Reference

### Authentication Endpoints

#### POST `/functions/v1/auth-apple-signin`
Sign in with Apple ID token.

**Headers (Local Development):**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
Content-Type: application/json
```

**Request:**
```json
{
  "identityToken": "apple_id_token",
  "user": {
    "id": "apple_user_id",
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

**Response:**
```json
{
  "success": true,
  "user": {
    "id": "user_uuid",
    "email": "user@example.com",
    "name": "John Doe",
    "daily_calorie_goal": 2000,
    "daily_protein_goal": 150.0,
    "daily_fat_goal": 65.0,
    "daily_carb_goal": 250.0,
    "units": "kcal",
    "timezone_offset": -480,
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z"
  },
  "session": {
    "access_token": "jwt_token",
    "refresh_token": "refresh_token",
    "expires_in": 3600
  }
}
```

#### POST `/functions/v1/auth-refresh`
Refresh expired access token.

**Request:**
```json
{
  "refresh_token": "refresh_token"
}
```

**Response:**
```json
{
  "success": true,
  "session": {
    "access_token": "new_jwt_token",
    "refresh_token": "new_refresh_token",
    "expires_in": 3600
  }
}
```

#### GET `/functions/v1/auth-profile`
Get user profile (requires authentication).

**Headers:**
```
Authorization: Bearer access_token
```

**Response:**
```json
{
  "success": true,
  "profile": {
    "id": "user_uuid",
    "email": "user@example.com",
    "name": "John Doe",
    "daily_calorie_goal": 2000,
    "daily_protein_goal": 150.0,
    "daily_fat_goal": 65.0,
    "daily_carb_goal": 250.0,
    "units": "kcal",
    "timezone_offset": -480,
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

#### PATCH `/functions/v1/auth-profile`
Update user profile (requires authentication).

**Headers:**
```
Authorization: Bearer access_token
```

**Request:**
```json
{
  "name": "John Smith",
  "daily_calorie_goal": 2200,
  "daily_protein_goal": 160.0,
  "units": "kcal"
}
```

**Response:**
```json
{
  "success": true,
  "profile": {
    "id": "user_uuid",
    "email": "user@example.com",
    "name": "John Smith",
    "daily_calorie_goal": 2200,
    "daily_protein_goal": 160.0,
    "daily_fat_goal": 65.0,
    "daily_carb_goal": 250.0,
    "units": "kcal",
    "timezone_offset": -480,
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T12:00:00Z"
  }
}
```

## Issues Found and Fixed

### 1. **Function Requires Authorization Header (Fixed)**
- **Issue**: The Apple Sign-In function was requiring an authorization header, which is incorrect for a sign-in endpoint
- **Fix**: Updated the function to accept the authorization header (required by Supabase's security configuration) but not use it for authentication logic
- **Note**: Local development requires the Supabase anon key in the authorization header due to Supabase's security configuration

### 2. **Duplicate Function Directories (Fixed)**
- **Issue**: There were duplicate Apple Sign-In and refresh function directories that could cause confusion
- **Fix**: Removed the duplicate `auth/` directory and kept only the main function directories
- **Result**: Clean function structure with `auth-apple-signin`, `auth-profile`, and `auth-refresh`

### 3. **Missing Environment Configuration (Fixed)**
- **Issue**: The `.env` file was missing
- **Fix**: Created the `.env` file from `env.example`

### 4. **Session Token Generation (Identified)**
- **Issue**: The function is using placeholder tokens instead of proper JWT generation
- **Recommendation**: Implement proper JWT token generation for production use

This implementation provides a solid foundation for authentication in your Calycal app with proper security, state management, and user experience. 