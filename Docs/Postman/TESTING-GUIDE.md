# CalCalCal Backend Testing Guide

## Overview

This guide walks you through testing the CalCalCal backend API using Postman. The backend has been migrated from Supabase to a custom Node.js + PostgreSQL stack.

## Prerequisites

1. **Backend Running**: Ensure the Node.js backend is running on `http://localhost:3000`
2. **Database Setup**: PostgreSQL database should be initialized with migrations
3. **Postman Installed**: Download from [postman.com](https://www.postman.com)

## Quick Start

### 1. Import Files into Postman

1. **Import Environment**:
   - File → Import → `Calcalcal.postman_environment.json`
   - Select the "CalCalCal Local" environment

2. **Import Collection**:
   - File → Import → `Calcalcal-API-Tests.postman_collection.json`
   - This contains all test requests organized by feature

### 2. Start Backend Server

```bash
cd apps/backend/node
npm run dev
```

You should see:
```
✅ Server running on http://localhost:3000
```

### 3. Run Tests in Order

The collection is organized to run tests in the correct sequence:

## Test Sequence

### Step 1: Health Check ✅
- **Request**: `GET /health`
- **Expected**: `200 OK` with `{"status":"ok","timestamp":"..."}`
- **Purpose**: Verify server is running

### Step 2: Authentication Flow 🔐

#### 2.1 Apple Sign-In (Test)
- **Request**: `POST /api/auth/signin-apple`
- **Body**: Test user data (no real Apple token needed for MVP)
- **Expected**: `200 OK` with user data and session tokens
- **Auto-saves**: `ACCESS_TOKEN` and `REFRESH_TOKEN` to environment

#### 2.2 Get Profile
- **Request**: `GET /api/auth/profile`
- **Headers**: `Authorization: Bearer {{ACCESS_TOKEN}}`
- **Expected**: `200 OK` with user profile data

#### 2.3 Refresh Token
- **Request**: `POST /api/auth/refresh`
- **Body**: `{"refresh_token": "{{REFRESH_TOKEN}}"}`
- **Expected**: `200 OK` with new tokens
- **Auto-saves**: Updated tokens to environment

### Step 3: Diary CRUD Operations 📝

#### 3.1 Create Diary Entry
- **Request**: `POST /api/diary/entries`
- **Body**: `{"date": "2025-01-15", "content": "Had two eggs and toast..."}`
- **Expected**: `201 Created` with entry data
- **Auto-saves**: `ENTRY_ID` to environment
- result: gives 500 internal server error. {
    "error": "Failed to create entry"
}

#### 3.2 Get Entry by ID
- **Request**: `GET /api/diary/entries/{{ENTRY_ID}}`
- **Expected**: `200 OK` with full entry data

#### 3.3 List Entries by Date Range
- **Request**: `GET /api/diary/entries?dateFrom=2025-01-01&dateTo=2025-01-31`
- **Expected**: `200 OK` with array of entries

#### 3.4 Update Entry Content
- **Request**: `PATCH /api/diary/entries/{{ENTRY_ID}}`
- **Body**: `{"content": "Updated content..."}`
- **Expected**: `200 OK` with updated entry

#### 3.5 Delete Entry
- **Request**: `DELETE /api/diary/entries/{{ENTRY_ID}}`
- **Expected**: `200 OK` with `{"success": true}`

### Step 4: AI Analysis 🤖

#### 4.1 Analyze Food Blocks
- **Request**: `POST /api/ai/analyze`
- **Body**: Entry ID and food blocks array
- **Expected**: `200 OK` with analysis results
- **Note**: Requires `OPENAI_API_KEY` in environment

### Step 5: Error Testing ❌

#### 5.1 Unauthorized Request
- **Request**: `GET /api/auth/profile` (no auth header)
- **Expected**: `401 Unauthorized`

#### 5.2 Invalid Token
- **Request**: `GET /api/auth/profile` with invalid token
- **Expected**: `401 Unauthorized`

#### 5.3 Missing Required Fields
- **Request**: `POST /api/diary/entries` without date
- **Expected**: `400 Bad Request`

## Running Tests

### Option 1: Manual Testing
1. Select the "CalCalCal Local" environment
2. Run requests one by one in the order listed above
3. Check responses match expected results

### Option 2: Collection Runner
1. Click "..." next to the collection name
2. Select "Run collection"
3. Choose the "CalCalCal Local" environment
4. Click "Run CalCalCal API Tests"

### Option 3: Newman (Command Line)
```bash
# Install Newman globally
npm install -g newman

# Run tests
newman run "Calcalcal-API-Tests.postman_collection.json" \
  -e "Calcalcal.postman_environment.json" \
  --reporters cli,html \
  --reporter-html-export report.html
```

## Expected Results

### ✅ Success Indicators
- All requests return expected HTTP status codes
- Authentication tokens are automatically saved
- Diary entries can be created, read, updated, and deleted
- AI analysis returns nutrition data (if OpenAI key is configured)
- Error cases return appropriate error messages

### ❌ Common Issues

#### Database Connection Error
```
Error: connect ECONNREFUSED 127.0.0.1:5432
```
**Solution**: Start PostgreSQL service
```bash
brew services start postgresql
```

#### Missing Environment Variables
```
Error: JWT_SECRET is not defined
```
**Solution**: Check `.env.local` file in backend directory

#### OpenAI API Error
```
Error: OpenAI API key not configured
```
**Solution**: Set `OPENAI_API_KEY` in environment or skip AI tests

#### Port Already in Use
```
Error: listen EADDRINUSE :::3000
```
**Solution**: Kill process using port 3000 or change PORT in `.env.local`

## Test Data

The collection uses these test values (configurable in environment):

- **Test User**: `com.apple.user.test123`
- **Test Email**: `test@example.com`
- **Test Name**: `Test User`
- **Test Date**: `2025-01-15`
- **Date Range**: `2025-01-01` to `2025-01-31`

## Next Steps

After successful testing:

1. **Deploy to Production**: Use the deployment guide in `BACKEND-MIGRATION.md`
2. **Update iOS App**: Change API endpoints in iOS configuration
3. **Monitor Performance**: Check response times and error rates
4. **Add More Tests**: Create additional test cases for edge scenarios

## Troubleshooting

### Backend Not Starting
```bash
# Check if port is available
lsof -i :3000

# Check Node.js version
node --version

# Check dependencies
npm install
```

### Database Issues
```bash
# Check PostgreSQL status
brew services list | grep postgresql

# Connect to database
psql -d calcalcal_dev

# Run migrations
npm run migrate
```

### Postman Issues
- Clear cache: File → Settings → Clear cache
- Check environment variables are set
- Verify request URLs match backend endpoints
- Check console for JavaScript errors in test scripts

## Support

If you encounter issues:
1. Check the backend logs in `apps/backend/node/logs/`
2. Verify all environment variables are set
3. Ensure database is running and accessible
4. Check Postman console for test script errors

---

**Happy Testing! 🚀**
