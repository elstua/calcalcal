# Streaks Feature Testing Guide

This guide provides step-by-step instructions for testing the streaks functionality in CalCalCal, covering both manual testing and automated testing approaches.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Manual API Testing](#manual-api-testing)
4. [Automated Testing](#automated-testing)
5. [Integration Testing](#integration-testing)
6. [Test Scenarios](#test-scenarios)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

Before testing the streaks functionality, ensure you have:

- Node.js 20.x installed
- PostgreSQL database running
- Backend code repository access
- Basic knowledge of REST APIs
- curl or Postman for API testing

## Environment Setup

### 1. Database Setup

```bash
# Ensure PostgreSQL is running
brew services start postgresql  # macOS
# or
sudo systemctl start postgresql  # Linux

# Create database (if not exists)
createdb calcalcal_dev
```

### 2. Backend Setup

```bash
# Navigate to backend directory
cd apps/backend/node

# Install dependencies
npm install

# Set up environment variables
cp ENV.example .env.local
# Edit .env.local with your database URL and other settings

# Run database migrations
npm run migrate

# Start the development server
npm run dev
```

The server should start on `http://localhost:3000`.

### 3. Verify Server Health

```bash
curl http://localhost:3000/health
# Expected response: {"status":"ok","timestamp":"..."}
```

## Manual API Testing

### 1. Create Test User

```bash
# Create temporary user
curl -X POST http://localhost:3000/api/auth/create-temporary \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"test-device-'$(date +%s)'"}'

# Save the user ID and access token from the response
# Response format:
# {
#   "success": true,
#   "user": { "id": "user-uuid", ... },
#   "session": { "access_token": "jwt-token", ... }
# }
```

### 2. Test Streaks Endpoints

Replace `YOUR_JWT_TOKEN` with the access token from the previous step.

#### Get Current Streaks

```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:3000/api/streaks

# Expected response for new user:
# {
#   "currentStreak": 0,
#   "longestStreak": 0,
#   "totalDaysWithEntries": 0,
#   "lastEntryDate": null,
#   "streakStartDate": null
# }
```

#### Get Streak History

```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:3000/api/streaks/history

# Expected response:
# {
#   "streaks": [],
#   "total": 0
# }
```

#### Get Streak Statistics

```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:3000/api/streaks/statistics

# Expected response:
# {
#   "currentStreak": 0,
#   "longestStreak": 0,
#   "totalDaysWithEntries": 0,
#   "averageStreakLength": 0,
#   "totalCompletedStreaks": 0,
#   "recentStreaks": []
# }
```

### 3. Create Diary Entries and Test Streak Calculation

#### Create Consecutive Entries (5-day streak)

```bash
# Create entries for 5 consecutive days
for i in {4..0}; do
  date=$(date -d "$i days ago" +%Y-%m-%d)
  curl -X POST http://localhost:3000/api/diary/entries \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer YOUR_JWT_TOKEN" \
    -d "{
      \"date\": \"$date\",
      \"content\": \"Healthy eating day $((5-i)). Had salad and grilled chicken for lunch.\",
      \"blocks\": [],
      \"total_calories\": 500
    }"
  echo "Created entry for $date"
  sleep 0.5
done
```

#### Check Streak After Consecutive Entries

```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:3000/api/streaks

# Expected: currentStreak should be 5
```

#### Test Streak Break

```bash
# Create an entry with placeholder content (should not count)
curl -X POST http://localhost:3000/api/diary/entries \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d "{
    \"date\": \"$(date -d '1 day ago' +%Y-%m-%d)\",
    \"content\": \"What did you eat today?\",
    \"blocks\": [],
    \"total_calories\": 0
  }"

# Check streaks - should remain unchanged
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:3000/api/streaks
```

#### Test Recalculation

```bash
curl -X POST http://localhost:3000/api/streaks/recalculate \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Expected: Returns corrected streaks data
```

## Automated Testing

### 1. Run the Test Suite

```bash
cd apps/backend/node

# Run all tests
npm test

# Run only streaks tests
npm test -- streaks.test.ts

# Run tests with coverage
npm test -- --coverage
```

### 2. Test Suite Structure

The automated tests cover:

- **StreaksModel Tests**: Database operations and data integrity
- **StreakCalculator Tests**: Business logic and edge cases
- **Integration Tests**: API endpoints and trigger functionality

### 3. Key Test Cases

```typescript
// Example test cases covered:
describe('Streaks Functionality', () => {
  test('should initialize streaks for new user')
  test('should calculate streaks from consecutive entries')
  test('should handle streak breaks correctly')
  test('should ignore placeholder content')
  test('should update streaks when meaningful entry is created')
  test('should not update streaks for placeholder content')
  test('should recalculate streaks correctly')
  test('should get streak statistics')
});
```

## Integration Testing

### 1. End-to-End Test Script

Use the provided test script for comprehensive testing:

```bash
cd apps/backend/node
node test-streaks.js
```

This script:
- Creates a test user
- Tests all streaks scenarios
- Validates API responses
- Cleans up test data

### 2. Postman Collection

Import the Postman collection from `Docs/Postman/`:

1. Open Postman
2. File → Import → Select `Calcalcal-API-Tests.postman_collection.json`
3. Set up environment variables:
   - `baseUrl`: http://localhost:3000
   - `token`: Your JWT token
4. Run the "Streaks Tests" folder

## Test Scenarios

### Scenario 1: New User Streaks

**Steps:**
1. Create new user
2. Check initial streaks (should be 0)
3. Create meaningful diary entry
4. Verify streak increases to 1

**Expected Results:**
- Initial streaks: all zeros
- After entry: currentStreak = 1, totalDaysWithEntries = 1

### Scenario 2: Consecutive Day Streak

**Steps:**
1. Create entries for 5 consecutive days
2. Check streaks after each entry
3. Verify streak progression: 1, 2, 3, 4, 5

**Expected Results:**
- Final streaks: currentStreak = 5, longestStreak = 5

### Scenario 3: Streak Break

**Steps:**
1. Build a 3-day streak
2. Skip a day (no entry or placeholder entry)
3. Create entry on the following day
4. Check streaks

**Expected Results:**
- Streak resets to 1 after the break
- Previous streak moved to history

### Scenario 4: Placeholder Content

**Steps:**
1. Create entry with placeholder content
2. Check streaks (should not increase)
3. Create entry with meaningful content
4. Check streaks (should increase)

**Expected Results:**
- Placeholder entries ignored in streak calculation
- Only meaningful content counts toward streaks

### Scenario 5: Timezone Handling

**Steps:**
1. Update user timezone offset
2. Create entries near midnight boundary
3. Verify streak calculation respects timezone

**Expected Results:**
- Streaks calculated based on user's local timezone

## Performance Testing

### 1. Load Testing

```bash
# Test with multiple concurrent requests
npm install -g artillery
artillery run load-test-streaks.yml
```

### 2. Database Performance

```sql
-- Check query performance
EXPLAIN ANALYZE SELECT * FROM user_streaks WHERE user_id = 'test-user-id';
EXPLAIN ANALYZE SELECT * FROM streak_history WHERE user_id = 'test-user-id' ORDER BY end_date DESC;
```

## Troubleshooting

### Common Issues

#### 1. "Invalid token" Error

**Solution:** Ensure you're using the correct `access_token` from the `session` object in the user creation response.

#### 2. "Failed to create entry" Error

**Solution:** Check the database logs. This is usually caused by the streaks trigger having an error.

#### 3. Streaks Not Updating

**Solution:** 
- Verify the database trigger is working: `SELECT * FROM information_schema.triggers WHERE trigger_name = 'update_streak_on_diary_change'`
- Check the `has_meaningful_content` function
- Use the recalculation endpoint as a fallback

#### 4. Test Failures

**Solution:**
- Ensure database is clean before running tests
- Check that all migrations are applied
- Verify environment variables are correct

### Debug Commands

```bash
# Check database connections
cd apps/backend/node && psql "postgresql://localhost:5432/calcalcal_dev" -c "SELECT version();"

# Verify streaks tables exist
psql "postgresql://localhost:5432/calcalcal_dev" -c "\dt user_streaks"
psql "postgresql://localhost:5432/calcalcal_dev" -c "\dt streak_history"

# Check trigger status
psql "postgresql://localhost:5432/calcalcal_dev" -c "SELECT trigger_name, event_manipulation FROM information_schema.triggers WHERE table_name = 'diary_entries';"

# View recent entries
psql "postgresql://localhost:5432/calcalcal_dev" -c "SELECT user_id, date, content FROM diary_entries ORDER BY created_at DESC LIMIT 10;"

# Check streaks data
psql "postgresql://localhost:5432/calcalcal_dev" -c "SELECT * FROM user_streaks ORDER BY updated_at DESC LIMIT 5;"
```

## Test Data Cleanup

### Manual Cleanup

```bash
# Delete test user and all related data
curl -X DELETE http://localhost:3000/api/auth/delete-account \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Database Cleanup

```sql
-- Clean up all test data
DELETE FROM streak_history WHERE user_id IN (
  SELECT id FROM user_profiles WHERE email LIKE '%test%'
);
DELETE FROM user_streaks WHERE user_id IN (
  SELECT id FROM user_profiles WHERE email LIKE '%test%'
);
DELETE FROM diary_entries WHERE user_id IN (
  SELECT id FROM user_profiles WHERE email LIKE '%test%'
);
DELETE FROM user_profiles WHERE email LIKE '%test%';
```

## Success Criteria

The streaks functionality is considered working correctly when:

- ✅ All API endpoints return expected responses
- ✅ Automated test suite passes (12/12 tests)
- ✅ Streaks calculate correctly for consecutive days
- ✅ Streaks reset properly after breaks
- ✅ Placeholder content is ignored
- ✅ Database triggers work without errors
- ✅ Recalculation produces consistent results
- ✅ Performance remains acceptable under load

## Next Steps

After validating the backend:

1. **iOS Integration**: Test the iOS app with the backend
2. **UI Testing**: Verify streaks display correctly in the app
3. **User Acceptance Testing**: Test with real users
4. **Performance Monitoring**: Set up monitoring in production
5. **Documentation**: Update API documentation

---

For additional support or questions, refer to the project documentation or create an issue in the repository.