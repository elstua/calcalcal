# HealthKit Testing Quick Reference

## ⚡ Quick Test Checklist

### Setup (One Time)
- [ ] Use physical iOS device (not simulator)
- [ ] Add test data to Health app:
  - Weight: Health > Browse > Body Measurements > Weight > Add Data
  - Height: Health > Browse > Body Measurements > Height > Add Data
  - Biological Sex: Health > Profile > Edit
  - Date of Birth: Health > Profile > Edit

### Test 1: Permission Flow (5 min)
1. Delete app → Reinstall
2. Go through onboarding
3. Tap "Connect Apple Health" on HealthKit step
4. ✅ Verify: Apple's permission sheet appears
5. ✅ Grant permissions
6. ✅ Verify: Profile shows imported weight/height

**Console Check:**
```
[HealthKitStep] Imported weight: XX kg
[HealthKitStep] Imported height: XX cm
```

### Test 2: Write Nutrition Data (5 min)
1. Create diary entry: "chicken breast and rice"
2. Wait for AI analysis (check totals appear)
3. Open Health app > Browse > Nutrition > Dietary Energy
4. ✅ Verify: Entry appears with correct calories
5. ✅ Check: Protein, Carbs, Fat also appear

**Console Check:**
```
[HealthKit] Successfully saved nutrition data: XXX kcal, XXg protein...
```

### Test 3: Manual Sync (2 min)
1. Update weight in Health app
2. Open app Profile view
3. Tap "Sync Now"
4. ✅ Verify: Profile weight updates

**Console Check:**
```
[AppState] Importing HealthKit weight: XX kg
```

### Test 4: Auto-Sync Toggle (2 min)
1. Profile > Toggle "Auto sync" OFF
2. Create diary entry
3. ✅ Verify: No data written to HealthKit
4. ✅ Console shows: `Sync skipped - not available or disabled`

## 🐛 Debug Commands (Xcode Console)

```swift
// Print HealthKit status
po HealthKitDebugHelper.printStatus()

// Test reading health data
po Task { await HealthKitDebugHelper.testReadAllData() }

// Test writing nutrition data
po Task { await HealthKitDebugHelper.testWriteNutritionData() }

// Check today's nutrition data in HealthKit
po Task { await HealthKitDebugHelper.checkTodayNutritionData() }
```

## 🔍 What to Check

### In Health App
- **Nutrition Data**: Browse > Nutrition > Dietary Energy > Show All Data
- **Permissions**: Settings > Privacy & Security > Health > Calycal

### In App Console
- Look for `[HealthKit]` prefix logs
- Check for errors (❌) vs success (✅)
- Verify sync timestamps update

### In Profile View
- Connection status (green = connected)
- Last sync timestamp
- Health data values match Health app

## ⚠️ Common Issues

| Issue | Check | Fix |
|-------|-------|-----|
| Permission sheet doesn't appear | Info.plist has usage descriptions? | Add `NSHealthShareUsageDescription` |
| Data not in Health app | Write permissions granted? | Grant in Settings > Privacy > Health |
| Health data not importing | Health app has data? | Add test data manually |
| Sync not working | Auto-sync enabled? | Enable in Profile view |

## 📊 Success Indicators

✅ **Permission Flow Working:**
- Permission sheet appears
- Can grant/deny permissions
- UI updates correctly

✅ **Read Working:**
- Profile shows imported data
- Values match Health app
- Console shows read logs

✅ **Write Working:**
- Health app shows nutrition entries
- Values match diary totals
- No duplicates

✅ **Sync Working:**
- Manual sync updates Profile
- App launch sync works
- Toggle controls sync behavior

## 🎯 5-Minute Smoke Test

1. **Fresh install** → Grant permissions → Verify import
2. **Create diary entry** → Wait for analysis → Check Health app
3. **Update weight in Health app** → Sync in Profile → Verify update

If all 3 pass → ✅ HealthKit integration is working!

---

**Full testing guide:** See `HEALTHKIT-TESTING.md` for detailed scenarios


