# iOS App Migration: Supabase → Node.js Backend

## Overview

This document outlines all changes needed in the iOS app to migrate from Supabase to the custom Node.js backend.

**Production API URL**: `https://calycal-app-egy2b.ondigitalocean.app`

---

## Summary of Changes Required

### 1. Configuration & Setup
- [ ] Update `Configuration.swift` - Remove Supabase dependency, update URLs
- [ ] Update `Info.plist` - Change API URL, remove anon key
- [ ] Remove Supabase Swift package dependency (optional cleanup)

### 2. Authentication (AuthManager.swift)
- [ ] Update Apple Sign-In endpoint: `/functions/v1/apple-signin` → `/api/auth/signin-apple`
- [ ] Update Profile endpoint: `/functions/v1/auth-profile` → `/api/auth/profile`
- [ ] Update Refresh endpoint: `/auth/v1/token` → `/api/auth/refresh`
- [ ] Remove `apikey` header (Supabase-specific)
- [ ] Remove `Bearer {anonKey}` header from sign-in request
- [ ] Remove Supabase import (unused)

### 3. Diary API (DiaryAPI.swift)
- [ ] Replace PostgREST endpoints with REST API endpoints
- [ ] Update query syntax (remove PostgREST query params)
- [ ] Update request body format (single object vs array)
- [ ] Remove `apikey` header
- [ ] Update AI analysis endpoint: `/functions/v1/ai-analyze` → `/api/ai/analyze`

### 4. Testing
- [ ] Test authentication flow
- [ ] Test diary CRUD operations
- [ ] Test AI analysis

---

## Detailed Changes

### File 1: `calcalcal/Models/Configuration.swift`

**Current state:**
- Uses Supabase client
- Has `supabaseURL` and `supabaseAnonKey`
- Imports Supabase package

**Changes needed:**

```swift
// REMOVE:
import Supabase
let supabase = SupabaseClient(...)

// CHANGE:
static let supabaseURL: String = {
    #if DEBUG
    if let s = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String, !s.isEmpty {
        return s
    }
    return "http://localhost:3000"  // Local dev
    #else
    return Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String ?? "https://calycal-app-egy2b.ondigitalocean.app"
    #endif
}()

// REMOVE entirely:
static let supabaseAnonKey: String = { ... }()
```

**Note:** Rename `SUPABASE_URL` key in Info.plist to `API_URL` for clarity.

---

### File 2: `calcalcal/Info.plist`

**Changes needed:**

```xml
<!-- CHANGE: -->
<key>API_URL</key>
<string>https://calycal-app-egy2b.ondigitalocean.app</string>

<!-- REMOVE: -->
<!-- <key>SUPABASE_ANON_KEY</key> -->
<!-- <string>...</string> -->
```

---

### File 3: `calcalcal/Models/AuthManager.swift`

#### Change 1: Remove Supabase import
```swift
// REMOVE:
import Supabase  // Line 4 - not actually used, safe to remove
```

#### Change 2: Update Apple Sign-In endpoint (Line 389)
```swift
// BEFORE:
let urlString = "\(Configuration.supabaseURL)/functions/v1/apple-signin"

// AFTER:
let urlString = "\(Configuration.supabaseURL)/api/auth/signin-apple"
```

#### Change 3: Remove Supabase auth headers from sign-in (Lines 415-433)
```swift
// REMOVE these lines:
let authHeader = "Bearer \(Configuration.supabaseAnonKey)"
request.setValue(authHeader, forHTTPHeaderField: "Authorization")
// ... (all the JWT debugging code)

// NEW backend doesn't need anon key - just send the request body
```

#### Change 4: Update Profile endpoint (Line 194)
```swift
// BEFORE:
guard let url = URL(string: "\(Configuration.supabaseURL)/functions/v1/auth-profile") else {

// AFTER:
guard let url = URL(string: "\(Configuration.supabaseURL)/api/auth/profile") else {
```

#### Change 5: Update Refresh endpoint (Line 285)
```swift
// BEFORE:
let urlString = "\(Configuration.supabaseURL)/auth/v1/token?grant_type=refresh_token"
request.setValue(Configuration.supabaseAnonKey, forHTTPHeaderField: "apikey")
request.setValue("Bearer \(Configuration.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
let body: [String: Any] = ["refresh_token": refreshToken]

// AFTER:
let urlString = "\(Configuration.supabaseURL)/api/auth/refresh"
// Remove apikey header
// Remove Authorization header with anon key
let body: [String: Any] = ["refresh_token": refreshToken]
```

#### Change 6: Remove network testing code (Lines 311-382)
```swift
// OPTIONAL: Remove or update testNetworkConnection() and testFunctionsEndpoint()
// These test Supabase-specific endpoints that no longer exist
```

---

### File 4: `calcalcal/Models/DiaryAPI.swift`

#### Change 1: Remove Supabase-specific headers (Lines 63-65)
```swift
// REMOVE:
request.setValue(Configuration.supabaseAnonKey, forHTTPHeaderField: "apikey")
request.setValue("return=representation", forHTTPHeaderField: "Prefer")  // Line 67
```

#### Change 2: Update listEntries() - Line 84-100
```swift
// BEFORE:
let urlString = "\(base)/rest/v1/diary_entries?select=\(select)&user_id=eq.\(userId)&date=gte.\(dateFrom)&date=lte.\(dateTo)&order=date.desc"

// AFTER:
let urlString = "\(base)/api/diary/entries?dateFrom=\(dateFrom)&dateTo=\(dateTo)"
// Backend handles user_id from JWT token automatically
```

#### Change 3: Update getByDate() - Line 103-122
```swift
// BEFORE:
let urlString = "\(base)/rest/v1/diary_entries?select=\(select)&date=eq.\(date)&user_id=eq.\(userId)&limit=1"

// AFTER:
// Use listEntries with dateFrom=date&dateTo=date, then get first result
// OR create new endpoint: GET /api/diary/entries/date/:date
```

#### Change 4: Update getById() - Line 124-136
```swift
// BEFORE:
let urlString = "\(base)/rest/v1/diary_entries?select=\(select)&id=eq.\(id)&limit=1"

// AFTER:
let urlString = "\(base)/api/diary/entries/\(id)"
```

#### Change 5: Update getBlocksById() - Line 138-153
```swift
// BEFORE:
let urlString = "\(base)/rest/v1/diary_entries?select=blocks&id=eq.\(id)&limit=1"

// AFTER:
// Get full entry via getById(), then extract blocks from response
// OR extend getById() to include blocks in response
```

#### Change 6: Update insert() - Line 180-202
```swift
// BEFORE:
let urlString = "\(base)/rest/v1/diary_entries?on_conflict=user_id,date"
let payload: [String: Any] = [
    "user_id": userId,
    "date": date,
    "content": content,
    "images": [] as [String]
]
let body = try JSONSerialization.data(withJSONObject: [payload]) // Array!
request.setValue("resolution=merge-duplicates, return=representation", forHTTPHeaderField: "Prefer")

// AFTER:
let urlString = "\(base)/api/diary/entries"
let payload: [String: Any] = [
    "date": date,
    "content": content
    // user_id comes from JWT token automatically
    // images can be added later if needed
]
let body = try JSONSerialization.data(withJSONObject: payload) // Single object!
// Remove Prefer header
```

#### Change 7: Update updateContent() - Line 204-219
```swift
// BEFORE:
let urlString = "\(base)/rest/v1/diary_entries?id=eq.\(id)"
let payload: [String: Any] = ["content": content]

// AFTER:
let urlString = "\(base)/api/diary/entries/\(id)"
let payload: [String: Any] = ["content": content]
// Change method to PATCH
```

#### Change 8: Update analyze() - Line 229-257
```swift
// BEFORE:
let urlString = "\(base)/functions/v1/ai-analyze"

// AFTER:
let urlString = "\(base)/api/ai/analyze"
```

#### Change 9: Update analyzeIncremental() - Line 260-305
```swift
// BEFORE:
let urlString = "\(base)/functions/v1/ai-analyze"

// AFTER:
let urlString = "\(base)/api/ai/analyze"
// Check if backend supports incremental flag, or merge client-side
```

#### Change 10: Update clearEntryNutrition() - Line 308-331
```swift
// BEFORE:
let urlString = "\(base)/rest/v1/diary_entries?id=eq.\(entryId)"
let clearData: [String: Any] = [
    "blocks": "[]" as Any,  // String!
    ...
]

// AFTER:
let urlString = "\(base)/api/diary/entries/\(entryId)"
let clearData: [String: Any] = [
    "blocks": [] as [Any],  // Empty array, not string
    ...
]
```

#### Change 11: Update deleteEntry() - Line 334-344
```swift
// BEFORE:
let urlString = "\(base)/rest/v1/diary_entries?id=eq.\(entryId)"

// AFTER:
let urlString = "\(base)/api/diary/entries/\(entryId)"
```

---

### File 5: `calcalcal/Models/APIClient.swift`

**No changes needed** - Already uses `Configuration.supabaseURL` which will be updated.

---

### File 6: Package Dependencies (Optional Cleanup)

**Project.swift** or **Package.swift**:
- Remove Supabase Swift package dependency
- This is optional - the app will work fine even if the package remains

---

## Response Format Changes

### Authentication Response

**Supabase format:**
```json
{
  "success": true,
  "user": { ... },
  "session": {
    "access_token": "...",
    "refresh_token": "...",
    "expires_in": 3600
  }
}
```

**New backend format:** (Should be the same! Check backend routes)

### Diary Entry Response

**Supabase (PostgREST):**
```json
[
  {
    "id": "...",
    "user_id": "...",
    "date": "2024-01-15",
    ...
  }
]
```

**New backend:**
```json
{
  "id": "...",
  "user_id": "...",
  "date": "2024-01-15",
  ...
}
```

**OR for list:**
```json
[
  { "id": "...", ... },
  { "id": "...", ... }
]
```

**Note:** Check actual backend response format by testing endpoints.

---

## Migration Checklist

### Phase 1: Configuration
- [ ] Update `Configuration.swift` - Remove Supabase, update URL
- [ ] Update `Info.plist` - Change URL key, remove anon key
- [ ] Test that app builds

### Phase 2: Authentication
- [ ] Update Apple Sign-In endpoint
- [ ] Update Profile endpoint  
- [ ] Update Refresh endpoint
- [ ] Remove Supabase headers
- [ ] Test sign-in flow
- [ ] Test profile loading
- [ ] Test token refresh

### Phase 3: Diary API
- [ ] Update all diary endpoints
- [ ] Fix request body formats
- [ ] Remove PostgREST query syntax
- [ ] Test list entries
- [ ] Test get entry
- [ ] Test create entry
- [ ] Test update entry
- [ ] Test delete entry

### Phase 4: AI Analysis
- [ ] Update AI analysis endpoint
- [ ] Test analysis flow

### Phase 5: Cleanup
- [ ] Remove unused Supabase imports
- [ ] Remove network testing code (optional)
- [ ] Remove Supabase package (optional)

---

## Testing Strategy

1. **Start with authentication** - If auth doesn't work, nothing else will
2. **Test each endpoint individually** - Use Postman to verify backend responses
3. **Compare response formats** - Ensure iOS code matches backend response structure
4. **Test error cases** - Invalid tokens, network errors, etc.

---

## Common Issues & Solutions

### Issue: "Missing authorization header"
**Solution:** Ensure Bearer token is set from session, not anon key

### Issue: "404 Not Found"
**Solution:** Check endpoint URLs match backend routes exactly

### Issue: "Invalid request body"
**Solution:** Backend expects single object, not array (for POST/PATCH)

### Issue: "Unauthorized"
**Solution:** Verify JWT token is valid and included in Authorization header

---

## Next Steps

1. Review this document
2. Make changes file by file
3. Test each component after changes
4. Update this document if backend responses differ from expectations

