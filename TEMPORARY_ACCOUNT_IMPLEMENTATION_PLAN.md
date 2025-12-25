# Temporary Account Onboarding Implementation Plan

## Overview
This document outlines the implementation of a temporary account system that allows users to start onboarding immediately without authentication, with the option to upgrade to a full account later.

## Current Architecture Analysis

### Current Flow
1. App launch → ContentView.swift checks authentication
2. Not authenticated → LoginView.swift (Apple/Google sign-in only)
3. Authenticated → OnboardingContainerView.swift → MainTabView.swift

### Key Components
- **AuthManager.swift**: Handles JWT tokens, OAuth authentication
- **AppState.swift**: Man app state, authentication status
- **OnboardingCoordinator.swift**: Manages onboarding flow
- **User model**: Already supports optional OAuth identifiers

## New User Flow

### Temporary Account Path
1. App launch → AuthChoiceView.swift (NEW)
2. Tap "Continue" → Create temporary account automatically
3. Redirect to OnboardingContainerView.swift
4. Complete onboarding → MainTabView.swift
5. Later option to upgrade from ProfileView.swift

### Traditional Sign-up Path
1. App launch → AuthChoiceView.swift
2. Tap "Sign up" Apple/Google authentication buttons → OnboardingContainerView.swift
3. Complete onboarding → MainTabView.swift

## New Screen
AuthChoiceView.swift
Working as welcome screen, that tells simply what's the application is and entry point.
Structure is simple:

1. header "Calycal"
2. Short description "intellegent calorie tracker for those who love a good food"
3. buttons
  1. "Learn more" -> temporary accoount path
  2. Already have an account? Sign in (small subheadline)
  3. Apple button / Google button (HStack splitted 50/50)


## Implementation Tasks

### Phase 1: Backend Changes

#### 1. Database Migration
**File**: `apps/backend/node/migrations/006_add_temporary_account_support.sql`
```sql
-- Add support for temporary accounts
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS is_temporary BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS device_id TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS created_via TEXT; -- 'apple', 'google', 'temporary'

-- Index for cleanup operations
CREATE INDEX IF NOT EXISTS idx_user_profiles_temporary_created_at 
ON user_profiles(is_temporary, created_at) 
WHERE is_temporary = TRUE;
```

#### 2. Update User Model
**File**: `apps/backend/node/src/models/User.ts`
- Add `createTemporaryUser(deviceId: string)` method
- Add `upgradeTemporaryAccount(userId, appleId, googleId, email, name)` method
- Update `upsertUser()` to handle temporary account creation

#### 3. New Authentication Endpoints
**File**: `apps/backend/node/src/routes/auth.ts`
- `POST /api/auth/create-temporary` - Creates temporary account
- `POST /api/auth/upgrade-temporary` - Upgrades temporary account with OAuth
- Update existing endpoints to handle temporary account upgrades

#### 4. Authentication Service Updates
**File**: `apps/backend/node/src/services/auth.ts`
- Add temporary account token generation
- Handle device ID management
- Update token validation for temporary users

### Phase 2: iOS Changes

#### 1. Create New Auth Choice Screen
**File**: `calcalcal/Views/AuthChoiceView.swift` (NEW)

#### 2. Update AuthManager
**File**: `calcalcal/Models/AuthManager.swift`
- Add `createTemporaryAccount()` method
- Add `upgradeTemporaryAccount(appleId: String?, googleId: String?)` method
- Add `isTemporaryUser` property
- Update session management to handle temporary accounts

#### 3. Modify Main App Flow
**File**: `calcalcal/Views/ContentView.swift`
- Replace `LoginView()` with `AuthChoiceView()`
- Update routing logic for temporary account detection

#### 4. Update Onboarding Coordinator
**File**: `calcalcal/Onboarding/OnboardingCoordinator.swift`
- Ensure onboarding data gets synced to backend for temporary accounts
- Add completion handler for temporary vs permanent account flows

#### 5. Add Account Upgrade Option
**File**: `calcalcal/Profile/ProfileView.swift`
- Add "Create Account" button for temporary users
- Implement account upgrade flow
- Handle data preservation during upgrade

#### 6. Update AppState
**File**: `calcalcal/Models/AppState.swift`
- Add `isTemporaryUser` property
- Update authentication state management
- Handle temporary account detection on app launch

### Phase 3: Testing & Cleanup

#### 1. Backend Testing
**File**: `apps/backend/node/src/test/auth-temporary.test.ts` (NEW)
- Test temporary account creation
- Test account upgrade flow
- Test data persistence during upgrade
- Test cleanup of abandoned accounts

#### 2. iOS Testing
- End-to-end flow testing for temporary accounts
- Upgrade flow testing
- Error handling testing
- Data integrity verification

#### 3. Cleanup Strategy
- Backend: Add background job to clean up temporary accounts older than 30 days with no data
- iOS: Add user warnings when abandoning temporary accounts
- Analytics: Track temporary account conversion rates

## Key Implementation Details

### Temporary Account Creation Process
1. Generate unique device identifier
2. Create user record with `is_temporary = true`
3. Generate JWT tokens like normal authentication
4. Store session in Keychain
5. Proceed to onboarding immediately

### Account Upgrade Process
1. User initiates OAuth authentication
2. Send current user ID with OAuth request
3. Backend links OAuth to existing temporary account
4. Set `is_temporary = false`
5. Update OAuth identifiers
6. All existing data remains associated with user

### Data Persistence
- Diary entries: Remain associated during upgrade
- Onboarding data: Synced to backend before upgrade
- User preferences: Preserved during upgrade

### Error Handling
- Network failures during temporary account creation
- OAuth failures during upgrade
- Session expiration for temporary users
- Data conflicts during upgrade

## Dependencies & Risks

### Dependencies
- JWT token system already implemented ✅
- User model already supports optional OAuth ✅
- Onboarding flow already exists ✅
- Backend migration system in place ✅

### Risks
- Data loss during upgrade if process fails
- Abandoned temporary accounts consuming resources
- User confusion about account status
- Security implications of temporary accounts

### Mitigations
- Implement robust error handling and rollback
- Add cleanup jobs for abandoned accounts
- Clear UI indicators for account status
- Temporary accounts have same security as regular accounts

## Timeline Estimate

- **Phase 1 (Backend)**: 4-6 hours
- **Phase 2 (iOS)**: 6-8 hours  
- **Phase 3 (Testing)**: 3-4 hours
- **Total**: 13-18 hours

## Success Criteria

1. Users can start onboarding without authentication
2. All onboarding data is preserved during account upgrade
3. Existing OAuth authentication flow remains unchanged
4. Temporary accounts have same functionality as permanent accounts
5. Clean upgrade process with no data loss
6. Proper cleanup of abandoned temporary accounts

## Next Steps

1. Review and approve this plan
2. Create database migration
3. Implement backend endpoints
4. Create AuthChoiceView
5. Update iOS authentication flow
6. Test end-to-end flow
7. Deploy to staging for testing
