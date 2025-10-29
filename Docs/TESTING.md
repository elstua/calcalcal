# CalCalCal Backend Testing Documentation

## Overview

This document provides comprehensive testing guidance for the CalCalCal backend migration from Supabase to Node.js + PostgreSQL. The backend includes authentication, diary CRUD operations, and AI analysis features.

## Table of Contents

1. [Testing Strategy](#testing-strategy)
2. [Prerequisites](#prerequisites)
3. [Test Files](#test-files)
4. [Quick Start](#quick-start)
5. [Test Scenarios](#test-scenarios)
6. [Running Tests](#running-tests)
7. [Expected Results](#expected-results)
8. [Troubleshooting](#troubleshooting)
9. [Next Steps](#next-steps)

## Testing Strategy

### Why Testing is Critical

- **API Validation**: Ensure all endpoints work correctly before iOS integration
- **Authentication Flow**: Verify Apple Sign-In and JWT token handling
- **Data Integrity**: Confirm diary entries are stored and retrieved properly
- **AI Integration**: Test OpenAI analysis functionality
- **Error Handling**: Validate proper error responses and edge cases
- **Performance**: Identify bottlenecks and optimize response times

### Testing Approach

1. **Manual Testing** - Using Postman for interactive testing
2. **Automated Testing** - Using Newman for CI/CD integration
3. **Simple Testing** - Using curl scripts for quick validation

## Prerequisites

### Required Software
- **Node.js** (v20.x or later)
- **PostgreSQL** (running locally)
- **Postman** (for manual testing)
- **Newman** (for automated testing)

### Backend Setup
```bash
# Navigate to backend directory
cd apps/backend/node

# Install dependencies
npm install

# Set up environment variables
cp ENV.example .env.local
# Edit .env.local with your configuration

# Run database migrations
npm run migrate

# Start the backend
npm run dev
```

### Database Setup
```bash
# Start PostgreSQL
brew services start postgresql

# Create database
createdb calcalcal_dev

# Verify connection
psql -d calcalcal_dev -c "SELECT version();"
```

## Test Files

### Postman Collection
- **File**: `Docs/Postman/Calcalcal-API-Tests.postman_collection.json`
- **Purpose**: Complete API test suite with organized requests
- **Features**: 
  - Automatic token extraction
  - Environment variable management
  - Test assertions
  - Error scenario coverage

### Postman Environment
- **File**: `Docs/Postman/Calcalcal.postman_environment.json`
- **Purpose**: Configuration and variable management
- **Variables**:
  - `BASE_URL`: Backend server URL
  - `ACCESS_TOKEN`: JWT access token
  - `REFRESH_TOKEN`: JWT refresh token
  - `ENTRY_ID`: Diary entry ID for testing
  - Test data variables

### Test Scripts
- **File**: `Docs/Postman/test-api.sh`
- **Purpose**: Simple curl-based testing
- **Features**: Automated test execution with colored output

- **File**: `Docs/Postman/run-tests.sh`
- **Purpose**: Newman-based automated testing
- **Features**: HTML report generation

## Quick Start

### Option 1: Postman (Recommended)

1. **Import Files**:
   - Open Postman
   - Import `Calcalcal.postman_environment.json`
   - Import `Calcalcal-API-Tests.postman_collection.json`

2. **Select Environment**:
   - Choose "CalCalCal Local" environment
   - Verify `BASE_URL` is set to `http://localhost:3000`

3. **Start Backend**:
   ```bash
   cd apps/backend/node
   npm run dev
   ```

4. **Run Tests**:
   - Execute requests in order
   - Or use Collection Runner for automated execution

### Option 2: Command Line Testing

```bash
# Navigate to test directory
cd Docs/Postman

# Make scripts executable
chmod +x test-api.sh run-tests.sh

# Run simple curl tests
./test-api.sh

# Or run Newman tests
./run-tests.sh
```

## Test Scenarios

### 1. Health Check
- **Endpoint**: `GET /health`
- **Purpose**: Verify server is running
- **Expected**: `200 OK` with status information

### 2. Authentication Flow

#### Apple Sign-In
- **Endpoint**: `POST /api/auth/signin-apple`
- **Purpose**: Test user authentication
- **Body**: Test user data (no real Apple token needed for MVP)
- **Expected**: `200 OK` with user data and session tokens
- **Auto-saves**: Access and refresh tokens to environment

#### Get Profile
- **Endpoint**: `GET /api/auth/profile`
- **Headers**: `Authorization: Bearer {{ACCESS_TOKEN}}`
- **Purpose**: Verify token-based authentication
- **Expected**: `200 OK` with user profile

#### Refresh Token
- **Endpoint**: `POST /api/auth/refresh`
- **Body**: `{"refresh_token": "{{REFRESH_TOKEN}}"}`
- **Purpose**: Test token refresh mechanism
- **Expected**: `200 OK` with new tokens

### 3. Diary CRUD Operations

#### Create Entry
- **Endpoint**: `POST /api/diary/entries`
- **Body**: `{"date": "2025-01-15", "content": "Food description"}`
- **Purpose**: Test entry creation
- **Expected**: `201 Created` with entry data
- **Auto-saves**: Entry ID to environment

#### Get Entry by ID
- **Endpoint**: `GET /api/diary/entries/{{ENTRY_ID}}`
- **Purpose**: Test entry retrieval
- **Expected**: `200 OK` with full entry data

#### List Entries
- **Endpoint**: `GET /api/diary/entries?dateFrom=2025-01-01&dateTo=2025-01-31`
- **Purpose**: Test entry listing with date range
- **Expected**: `200 OK` with array of entries

#### Update Entry
- **Endpoint**: `PATCH /api/diary/entries/{{ENTRY_ID}}`
- **Body**: `{"content": "Updated content"}`
- **Purpose**: Test entry modification
- **Expected**: `200 OK` with updated entry

#### Delete Entry
- **Endpoint**: `DELETE /api/diary/entries/{{ENTRY_ID}}`
- **Purpose**: Test entry deletion
- **Expected**: `200 OK` with success confirmation

### 4. AI Analysis

#### Analyze Food Blocks
- **Endpoint**: `POST /api/ai/analyze`
- **Body**: Entry ID and food blocks array
- **Purpose**: Test OpenAI integration
- **Expected**: `200 OK` with nutrition analysis
- **Note**: Requires `OPENAI_API_KEY` in environment

### 5. Error Testing

#### Unauthorized Request
- **Endpoint**: `GET /api/auth/profile` (no auth header)
- **Expected**: `401 Unauthorized`

#### Invalid Token
- **Endpoint**: `GET /api/auth/profile` with invalid token
- **Expected**: `401 Unauthorized`

#### Missing Required Fields
- **Endpoint**: `POST /api/diary/entries` without date
- **Expected**: `400 Bad Request`

## Running Tests

### Manual Testing (Postman)

1. **Individual Requests**:
   - Select environment
   - Run requests one by one
   - Check responses and console logs

2. **Collection Runner**:
   - Click "..." next to collection
   - Select "Run collection"
   - Choose environment
   - Click "Run CalCalCal API Tests"

3. **Newman (Command Line)**:
   ```bash
   newman run "Calcalcal-API-Tests.postman_collection.json" \
     -e "Calcalcal.postman_environment.json" \
     --reporters cli,html \
     --reporter-html-export report.html
   ```

### Automated Testing

#### Simple Curl Tests
```bash
cd Docs/Postman
./test-api.sh
```

#### Newman Tests
```bash
cd Docs/Postman
./run-tests.sh
```

## Expected Results

### Success Indicators
- ✅ All requests return expected HTTP status codes
- ✅ Authentication tokens are automatically saved
- ✅ Diary entries can be created, read, updated, and deleted
- ✅ AI analysis returns nutrition data (if configured)
- ✅ Error cases return appropriate error messages
- ✅ Response times are reasonable (< 2 seconds)

### Test Data
- **Test User**: `com.apple.user.test123`
- **Test Email**: `test@example.com`
- **Test Name**: `Test User`
- **Test Date**: `2025-01-15`
- **Date Range**: `2025-01-01` to `2025-01-31`

## Troubleshooting

### Common Issues

#### Backend Not Starting
```bash
# Check if port is available
lsof -i :3000

# Check Node.js version
node --version

# Check dependencies
npm install
```

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

### Debugging Steps

1. **Check Backend Logs**:
   ```bash
   tail -f apps/backend/node/logs/backend-dev.log
   ```

2. **Verify Database**:
   ```bash
   psql -d calcalcal_dev -c "SELECT * FROM user_profiles LIMIT 1;"
   ```

3. **Test Individual Endpoints**:
   ```bash
   curl -v http://localhost:3000/health
   ```

4. **Check Environment Variables**:
   ```bash
   cd apps/backend/node
   cat .env.local
   ```

## Next Steps

### After Successful Testing

1. **Deploy to Production**:
   - Use deployment guide in `BACKEND-MIGRATION.md`
   - Set up production environment variables
   - Configure production database

2. **Update iOS App**:
   - Change API endpoints in iOS configuration
   - Update authentication flow if needed
   - Test iOS app with new backend

3. **Monitor Performance**:
   - Set up logging and monitoring
   - Track response times and error rates
   - Monitor database performance

4. **Add More Tests**:
   - Create additional test cases for edge scenarios
   - Add performance tests
   - Set up continuous integration

### Production Checklist

- [ ] All tests pass locally
- [ ] Environment variables configured
- [ ] Database migrations applied
- [ ] SSL certificates configured
- [ ] Monitoring and logging set up
- [ ] Backup strategy implemented
- [ ] Performance benchmarks established

## Support

If you encounter issues:

1. **Check Logs**: Review backend and database logs
2. **Verify Configuration**: Ensure all environment variables are set
3. **Test Connectivity**: Verify database and external API connections
4. **Review Documentation**: Check the backend migration guide
5. **Debug Step by Step**: Use individual curl commands to isolate issues

---

**Happy Testing! 🚀**

*This testing documentation ensures your CalCalCal backend migration is robust and ready for production.*