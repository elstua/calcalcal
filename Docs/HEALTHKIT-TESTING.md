# HealthKit Integration Testing Guide

## Prerequisites

### Required Setup

1. **Physical iOS Device** (iPhone or iPad)
   - HealthKit does NOT work fully on simulators
   - Must be running iOS 13.0 or later
   - Device must have Health app installed

2. **Health App Setup**
   - Open the Health app on your device
   - Add some test data manually:
     - **Weight**: Go to Health > Browse > Body Measurements > Weight > Add Data
     - **Height**: Go to Health > Browse > Body Measurements > Height > Add Data
     - **Biological Sex**: Set in Health > Profile (top right) > Edit
     - **Date of Birth**: Set in Health > Profile > Edit

3. **Xcode Console Access**
   - Connect device to Mac
   - Open Xcode > Window > Devices and Simulators
   - Select your device and click "Open Console" to view logs

## Testing Strategy

### Phase 1: Basic Functionality Testing

#### Test 1: HealthKit Availability Check

**Steps:**
1. Launch the app on a physical device
2. Check Xcode console for: `[HealthKit]` log messages
3. Verify HealthKit is detected as available

**Expected Result:**
- Console shows: `[HealthKit]` logs indicating availability
- No errors about HealthKit not being available

**How to Verify:**
```swift
// Check console logs
// Should see: HealthKit is available on this device
```

#### Test 2: Permission Request Flow (Onboarding)

**Steps:**
1. Delete app and reinstall (to reset permissions)
2. Go through onboarding flow
3. Reach the HealthKit step
4. Tap "Connect Apple Health" button

**Expected Result:**
- Apple's native HealthKit permission sheet appears
- Sheet shows all requested data types:
  - Weight (Read)
  - Height (Read)
  - Biological Sex (Read)
  - Date of Birth (Read)
  - Dietary Energy (Write)
  - Protein (Write)
  - Carbohydrates (Write)
  - Fat (Write)
- User can toggle individual permissions
- After granting permissions, UI updates to show "Connected" state

**How to Verify:**
- Check console for: `[HealthKitStep]` logs
- Verify permission sheet shows correct data types
- Check that onboarding data is populated after authorization

**Console Logs to Look For:**
```
[HealthKitStep] Requesting permissions...
[HealthKit] Authorization result: true
[HealthKitStep] Imported weight: XX kg
[HealthKitStep] Imported height: XX cm
[HealthKitStep] Imported gender: male/female/other
[HealthKitStep] Imported age: XX
```

#### Test 3: Reading Health Data

**Steps:**
1. Ensure Health app has test data (weight, height, etc.)
2. Complete onboarding with HealthKit permissions granted
3. Check Profile view

**Expected Result:**
- Profile shows imported weight and height
- Age is calculated from date of birth
- Gender is imported

**How to Verify:**
- Open Profile view
- Check "Health Information" section
- Values should match what's in Health app

**Console Logs:**
```
[HealthKit] Read weight: XX kg
[HealthKit] Read height: XX cm
[HealthKit] Read biological sex: male/female/other
[HealthKit] Calculated age: XX
```

#### Test 4: Writing Nutrition Data

**Steps:**
1. Create a diary entry with food
2. Wait for AI analysis to complete (check for nutrition totals)
3. Open Health app > Browse > Nutrition
4. Check "Dietary Energy" (Calories), Protein, Carbohydrates, Fat

**Expected Result:**
- Nutrition data appears in Health app
- Values match diary entry totals
- Data is dated correctly (same day as diary entry)

**How to Verify:**
- Health app > Browse > Nutrition > Dietary Energy
- Select "Show All Data"
- Find entry with today's date
- Verify calories, protein, carbs, fat match diary totals

**Console Logs:**
```
[HealthKit] Successfully saved nutrition data: XXX kcal, XXg protein, XXg carbs, XXg fat
[HealthKit] Successfully synced: XXX kcal, XXg protein, XXg carbs, XXg fat
```

### Phase 2: Edge Cases & Error Handling

#### Test 5: Permission Denial

**Steps:**
1. Delete app and reinstall
2. Go through onboarding
3. On HealthKit step, deny all permissions
4. Try to continue

**Expected Result:**
- App continues without crashing
- UI shows "Permission denied" state
- Skip option still works
- No data is imported

**How to Verify:**
- Check Profile view shows "Not connected" status
- No health data imported
- App functions normally without HealthKit

#### Test 6: Partial Permission Grant

**Steps:**
1. Delete app and reinstall
2. On HealthKit permission sheet, only grant:
   - Weight (Read) ✓
   - Height (Read) ✗
   - Biological Sex (Read) ✓
   - Date of Birth (Read) ✗
3. Continue onboarding

**Expected Result:**
- Only granted data types are imported
- Missing data types show "Not set" in Profile
- App handles partial data gracefully

**How to Verify:**
- Check Profile view
- Weight should be imported
- Height should show "Not set"
- Gender should be imported
- Age should show "Not set"

#### Test 7: No Health Data Available

**Steps:**
1. Use a device with empty Health app (or delete all data)
2. Grant HealthKit permissions
3. Try to sync

**Expected Result:**
- App handles gracefully
- Shows "No data available" or similar message
- Doesn't crash or show errors

**How to Verify:**
- Check console logs for: `[HealthKit] No weight data available`
- Profile view shows "Not set" for missing data

#### Test 8: Duplicate Prevention

**Steps:**
1. Create diary entry with food
2. Wait for sync to HealthKit
3. Edit the same diary entry (change food)
4. Wait for sync again

**Expected Result:**
- Old nutrition data is deleted first
- New data is written
- No duplicate entries in Health app

**How to Verify:**
- Health app > Nutrition > Dietary Energy > Show All Data
- Should see only ONE entry per day
- Latest entry matches current diary totals

**Console Logs:**
```
[HealthKit] Deleted X dietaryEnergyConsumed samples
[HealthKit] Successfully saved nutrition data...
```

### Phase 3: Sync Behavior Testing

#### Test 9: App Launch Sync

**Steps:**
1. Grant HealthKit permissions
2. Update weight/height in Health app
3. Close app completely
4. Reopen app
5. Check Profile view

**Expected Result:**
- On app launch, latest HealthKit data is read
- Profile updates if data changed significantly
- Sync happens automatically (if enabled)

**How to Verify:**
- Check console logs on app launch:
  ```
  [AppState] Starting HealthKit data sync on launch
  [HealthKit] Read weight: XX kg
  [AppState] Importing HealthKit weight: XX kg
  ```

#### Test 10: Manual Sync (Profile View)

**Steps:**
1. Update weight in Health app
2. Open app Profile view
3. Tap "Sync Now" button
4. Check Profile view updates

**Expected Result:**
- Button shows "Syncing..." while working
- Profile updates with latest data
- Success message appears
- Last sync timestamp updates

**How to Verify:**
- Check Profile view shows updated weight
- "Last synced" timestamp updates
- Console shows sync logs

#### Test 11: Auto-Sync Toggle

**Steps:**
1. Go to Profile view
2. Toggle "Auto sync" OFF
3. Create diary entry
4. Check Health app

**Expected Result:**
- Diary entry saves normally
- Nutrition data is NOT written to HealthKit
- Console shows: `[HealthKit] Sync skipped - not available or disabled`

**How to Verify:**
- Health app shows no new nutrition entries
- Console confirms sync was skipped

### Phase 4: Data Accuracy Testing

#### Test 12: Unit Conversion

**Steps:**
1. Set app to use Imperial units (lbs, inches)
2. Import weight/height from HealthKit (which uses metric)
3. Verify correct conversion

**Expected Result:**
- Weight converted from kg to lbs correctly
- Height converted from cm to inches correctly
- Display shows correct values

**How to Verify:**
- Profile view shows weight in lbs (if unit preference is lbs)
- Height shows in inches/feet (if unit preference is inches)
- Values match Health app data after conversion

#### Test 13: Age Calculation

**Steps:**
1. Set date of birth in Health app
2. Grant HealthKit permissions
3. Check Profile view

**Expected Result:**
- Age is calculated correctly from date of birth
- Age updates automatically as time passes

**How to Verify:**
- Profile shows correct age
- Console shows: `[HealthKit] Calculated age: XX`

#### Test 14: Nutrition Data Accuracy

**Steps:**
1. Create diary entry: "2 eggs and toast"
2. Wait for AI analysis
3. Note the totals (calories, protein, carbs, fat)
4. Check Health app

**Expected Result:**
- Health app values match diary totals exactly
- All macros are present (not just calories)
- Date matches diary entry date

**How to Verify:**
- Health app > Nutrition > Dietary Energy
- Compare values with diary entry totals
- Check all four data types: Energy, Protein, Carbs, Fat

## Debugging Tips

### Console Log Patterns

**Successful Operations:**
```
[HealthKit] Read weight: 70.5 kg
[HealthKit] Successfully saved nutrition data: 500 kcal, 30g protein, 50g carbs, 20g fat
[AppState] HealthKit sync skipped - not available or disabled
```

**Error Patterns:**
```
[HealthKit] Error reading weight: <error description>
[HealthKit] Sync error: <error description>
[HealthKit] Write permission denied
```

### Common Issues & Solutions

#### Issue: Permission Sheet Doesn't Appear

**Symptoms:**
- Button tap does nothing
- No permission sheet shown

**Debugging:**
1. Check console for errors
2. Verify `Info.plist` has usage descriptions
3. Check entitlements file has HealthKit capability
4. Verify device has Health app installed

**Solution:**
- Ensure `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` are in `Info.plist`
- Verify `com.apple.developer.healthkit` is in entitlements

#### Issue: Data Not Appearing in Health App

**Symptoms:**
- Diary entries save successfully
- No nutrition data in Health app

**Debugging:**
1. Check console for write errors
2. Verify write permissions were granted
3. Check if sync is enabled in Profile
4. Verify diary entry has nutrition totals (not zero)

**Solution:**
- Check console logs for `[HealthKit] Sync skipped` messages
- Verify "Auto sync" is enabled in Profile
- Ensure diary entry has non-zero nutrition values

#### Issue: Health Data Not Importing

**Symptoms:**
- Permissions granted
- Profile still shows "Not set"

**Debugging:**
1. Check Health app has data
2. Verify read permissions were granted
3. Check console for read errors
4. Try manual sync from Profile

**Solution:**
- Add test data to Health app manually
- Try "Sync Now" button in Profile
- Check console for read errors

### Testing Checklist

Use this checklist to ensure comprehensive testing:

- [ ] HealthKit availability check works
- [ ] Permission request shows correct data types
- [ ] Permission grant imports health data
- [ ] Permission denial handled gracefully
- [ ] Partial permissions work correctly
- [ ] Nutrition data writes to HealthKit
- [ ] Duplicate prevention works
- [ ] App launch sync works
- [ ] Manual sync works
- [ ] Auto-sync toggle works
- [ ] Unit conversion correct
- [ ] Age calculation correct
- [ ] Data accuracy verified
- [ ] Error handling works
- [ ] No crashes on edge cases

## Quick Test Script

Run through this quick test sequence:

1. **Fresh Install Test**
   ```bash
   # Delete app from device
   # Reinstall from Xcode
   # Go through onboarding
   # Grant HealthKit permissions
   # Verify data imports
   ```

2. **Nutrition Write Test**
   ```bash
   # Create diary entry: "chicken breast and rice"
   # Wait for AI analysis
   # Open Health app > Nutrition > Dietary Energy
   # Verify entry appears with correct values
   ```

3. **Sync Test**
   ```bash
   # Update weight in Health app
   # Open app Profile view
   # Tap "Sync Now"
   # Verify weight updates in Profile
   ```

## Advanced Testing

### Testing with Multiple Days

1. Create diary entries for multiple days
2. Verify each day's nutrition data appears in Health app
3. Check dates are correct
4. Verify no duplicates

### Testing with Large Values

1. Create diary entry with very high calories (e.g., 5000 kcal)
2. Verify HealthKit accepts large values
3. Check Health app displays correctly

### Testing Background Behavior

1. Create diary entry
2. Put app in background immediately
3. Wait for AI analysis
4. Verify sync still happens when app returns to foreground

## Monitoring in Production

### Key Metrics to Track

1. **Permission Grant Rate**
   - How many users grant HealthKit permissions?
   - Track in analytics

2. **Sync Success Rate**
   - How often does sync succeed vs fail?
   - Log errors for analysis

3. **Data Accuracy**
   - Spot check: Compare app totals with Health app entries
   - Verify no data loss

### Logging Strategy

All HealthKit operations are logged with `[HealthKit]` prefix. Monitor:
- Permission requests
- Read operations
- Write operations
- Errors
- Sync timestamps

## Troubleshooting Commands

### Check HealthKit Status
```swift
// In Xcode console or debugger
po HealthKitManager.shared.isAvailable
po HealthKitManager.shared.isSyncEnabled
po HealthKitManager.shared.lastSyncDate
```

### Force Permission Reset
```swift
// Delete app and reinstall
// Or reset permissions in Settings > Privacy > Health
```

### View Health App Data
```
Settings > Privacy & Security > Health > Calycal
Shows which data types are shared
```

---

**Remember:** HealthKit requires a physical device. Always test on real hardware, not simulators!





