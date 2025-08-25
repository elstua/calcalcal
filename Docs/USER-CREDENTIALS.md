# User Credentials: Collection, Storage, and Usage

## Overview
This document explains what user credentials we collect, how and when we collect them, where they are stored (device and backend), and how they are used across the iOS app and Supabase backend.

Applies to Sign in with Apple, the Supabase Edge Function `apple-signin`, session token storage, and profile persistence.

## Data we collect
- Apple Identity Token (short‑lived JWT from Apple)
- Apple user info (often only on first consent):
  - Full name
  - Email (can be Apple relay if “Hide My Email”)
  - Apple subject identifier (stable `sub`) captured as `apple_id`
- Supabase session after successful authentication:
  - `access_token`, `refresh_token`, `expires_in`

## Where collection happens
- iOS requests Apple scopes and obtains the credential
  - File: `calcalcal/Models/AuthManager.swift`
  - Scopes: `.fullName`, `.email`
- iOS POSTs to backend with `identityToken` plus first‑sign‑in name/email (if present)
  - Endpoint: `/functions/v1/apple-signin`

## Backend flow (Supabase Edge Function)
- File: `apps/backend/supabase/functions/apple-signin/index.ts`
- Steps
  1. Verify Apple identity token signature/issuer (best‑effort)
  2. Exchange Apple token for Supabase Auth session: `auth.signInWithIdToken({ provider: "apple", token })`
  3. Persist user profile with service role:
     - If no `user_profiles` row exists: insert `email`, `name`, `apple_id`
     - If row exists: only fill fields that are currently null (prevents overwriting with nulls on later sign‑ins)
     - Best‑effort mirror `name` and `apple_id` into Auth `user_metadata` on first sign‑in
  4. Return iOS‑friendly response `{ success, user, session }`

Rationale: Apple typically returns name/email only on first consent. The conditional write ensures we capture them once and never blank them later.

## Storage locations
- On device (iOS)
  - Supabase session (`access_token`, `refresh_token`, `expires_in`) stored securely in Keychain
  - Files:
    - `calcalcal/Models/KeychainManager.swift`
    - `calcalcal/Models/Session.swift`
- Backend (Supabase)
  - `auth.users` (managed by Supabase Auth)
    - Session + identities; `user_metadata` may include `name`, `apple_id` (set server‑side on first sign‑in)
  - `public.user_profiles` (app table)
    - Columns (subset): `id`, `email`, `name`, `apple_id`, `updated_at`

## How credentials are used
- iOS adds `Authorization: Bearer <access_token>` to authenticated requests
  - File: `calcalcal/Models/APIClient.swift`
- On app launch, iOS loads and validates any stored session with a protected profile endpoint
  - File: `calcalcal/Models/AuthManager.swift`
  - Invalid session -> Keychain is cleared and user is signed out
- The UI reads `currentUser` (from `user_profiles`) to display name/email and personalize screens

## Privacy and first‑sign‑in behavior
- Name/email are requested from Apple and generally returned only once (first consent)
- If user chooses Hide My Email, we store the Apple relay address as email
- Email can be null if Apple does not provide it; profile editing flow can later populate it

## Configuration and deployment
- Required environment variables for the Edge Function:
  - `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
  - `SUPABASE_AUTH_EXTERNAL_APPLE_SECRET` (Apple provider secret)
- Function name: `apple-signin` (canonical). Duplicate aliases should not be deployed.

## File map (key references)
- iOS
  - `calcalcal/Models/AuthManager.swift`
  - `calcalcal/Models/KeychainManager.swift`
  - `calcalcal/Models/APIClient.swift`
  - `calcalcal/Models/Session.swift`
- Backend
  - `apps/backend/supabase/functions/apple-signin/index.ts`
  - `apps/backend/supabase/config.toml` (Apple provider config)

## FAQ
- Why don’t we always get name/email from Apple?
  - Apple usually returns them only on the first consent. We store them once and avoid overwriting later.
- Can users edit their name/email later?
  - Yes, via a profile editing flow that updates `user_profiles` (when implemented).
