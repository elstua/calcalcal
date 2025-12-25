# Streaks Feature Implementation Plan

## Overview
Implement a streaks system that tracks consecutive days users add food entries to their diary, with both current streak tracking and historical streak data.

## Feature Requirements
1. **Current Streak**: Number of consecutive non-empty days
2. **Streak Reset**: Streak ends when user skips a day
3. **Historical Data**: Track previous streaks for display
4. **Visual Indicators**: Show streaks in DayStripView and other UI locations
5. **Backend Calculation**: Server-side streak tracking for consistency

## Implementation Plan

### Phase 1: Backend Database Schema

#### 1.1 Add Streaks Table
Create new table for streak tracking:
```sql
CREATE TABLE user_streaks (
    user_id UUID PRIMARY KEY REFERENCES user_profiles(id) ON DELETE CASCADE,
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    last_entry_date DATE,
    streak_start_date DATE,
    total_days_with_entries INTEGER DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_user_streaks_user_id ON user_streaks(user_id);
```

#### 1.2 Add Streak History Table
Track completed streaks:
```sql
CREATE TABLE streak_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    streak_length INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_streak_history_user_id ON streak_history(user_id);
```

#### 1.3 Database Migration
Create migration file: `007_add_streaks_tables.sql`

### Phase 2: Backend Logic Implementation

#### 2.1 Streaks Model
Create `apps/backend/node/src/models/Streaks.ts`:
- `getCurrentStreak(userId)` - get current streak info
- `updateStreak(userId, entryDate)` - update streak on new entry
- `recalculateStreaks(userId)` - recalculate from scratch
- `getStreakHistory(userId)` - get historical streaks

#### 2.2 Streak Calculation Service
Create `apps/backend/node/src/services/streakCalculator.ts`:
- Core streak calculation logic
- Handle timezone considerations
- Define "non-empty day" criteria
- Batch recalculation for data integrity

#### 2.3 API Endpoints
Add to `apps/backend/node/src/routes/streaks.ts`:
- `GET /api/streaks` - current streak info
- `GET /api/streaks/history` - historical streaks
- `POST /api/streaks/recalculate` - manual recalculation

#### 2.4 Integration Points
- Update diary entry creation/update to trigger streak updates
- Add middleware for automatic streak calculation
- Handle user deletion cleanup

### Phase 3: iOS API Integration

#### 3.1 Streaks Data Models
Add to `calcalcal/Models/`:
```swift
struct StreaksData: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let totalDaysWithEntries: Int
    let lastEntryDate: String?
    let streakStartDate: String?
}

struct StreakHistoryItem: Codable {
    let id: String
    let streakLength: Int
    let startDate: String
    let endDate: String
}
```

#### 3.2 API Client Extension
Extend `DiaryAPI` in `calcalcal/Models/DiaryAPI.swift`:
```swift
static func getStreaks() async throws -> StreaksData
static func getStreakHistory() async throws -> [StreakHistoryItem]
```

#### 3.3 State Management
Update `AppState` in `calcalcal/Models/AppState.swift`:
- Add `@Published var streaksData: StreaksData?`
- Add `@Published var streakHistory: [StreakHistoryItem]`
- Add loading states

### Phase 4: UI Implementation

#### 4.1 DayStripView Enhancement
Update `calcalcal/Views/DayStripView.swift`:
- Add flame icon to streak days
- Update `DayStripItemModel` to include `isInStreak: Bool`
- Visual distinction for streak days

#### 4.2 Header Integration
Add streak indicator to diary header:
- Compact "🔥 5" display next to "Diary" title
- Animated updates when streak changes
- Tap to view detailed streaks

#### 4.3 Profile Integration
Add streaks section to `ProfileView`:
- Current streak, longest streak, total days
- Recent streak history
- Achievement-style presentation

#### 4.4 Streak Detail Modal
Create new view for detailed streaks:
- Calendar view showing streak days
- Historical streaks list
- Statistics and insights

### Phase 5: Data Flow & Integration

#### 5.1 Streak Update Triggers
Update streaks when:
- New diary entry is created/updated
- Entry is deleted
- User logs in (initial load)
- Manual refresh requested

#### 5.2 Offline Support
- Local streak calculation using existing `dayEntryStates`
- Cache streaks data locally
- Sync when connectivity restored

#### 5.3 Error Handling
- Graceful fallback for API failures
- Local streak calculation as backup
- User feedback for sync issues

## Technical Considerations

### Streak Definition Rules
1. **Non-empty Day**: Entry with meaningful content (beyond placeholder prompts)
2. **Consecutive Days**: No gaps in dates (based on user's timezone)
3. **Streak Reset**: Missing a day resets current streak to 0
4. **Historical Tracking**: Completed streaks saved to history

### Timezone Handling
- Use user's `timezone_offset` from profile
- Calculate day boundaries based on user's local time
- Ensure consistent streak calculation across timezones

### Performance Optimization
- Efficient database queries with proper indexing
- Batch streak calculations for bulk updates
- Client-side caching to reduce API calls

### Data Integrity
- Database triggers for automatic streak updates
- Recalculation functions for data repair
- Validation checks for streak consistency

## Testing Strategy

### Backend Testing
- Unit tests for streak calculation logic
- Integration tests for API endpoints
- Database migration testing
- Timezone edge case testing

### iOS Testing
- API integration tests
- UI component tests for streak display
- State management testing
- Offline behavior testing

### User Acceptance Testing
- Streak accuracy validation
- UI usability testing
- Performance with large datasets
- Cross-timezone functionality

## Rollout Plan

### Phase 1: Backend Foundation (Week 1)
- Database schema implementation
- Core streak calculation logic
- Basic API endpoints

### Phase 2: API Integration (Week 2)
- iOS API client implementation
- State management setup
- Basic streak display

### Phase 3: UI Enhancement (Week 3)
- DayStripView streak display instead of "all day" button. Should work similarly to the existing button -- open view with all days
- Profile integration

### Phase 4: Polish & Features (Week 4)
- Streak detail modal
- Historical streaks display
- Offline support
- Performance optimization

### Phase 5: Testing & Launch (Week 5)
- Comprehensive testing
- Bug fixes
- Documentation updates
- Production deployment

## Success Metrics
- User engagement with streak feature
- Increase in daily logging consistency
- Positive user feedback on gamification
- Minimal performance impact
