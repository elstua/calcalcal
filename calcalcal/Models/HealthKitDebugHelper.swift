import Foundation
import HealthKit

#if DEBUG
/// Debug helper for testing HealthKit integration
/// Only available in DEBUG builds
struct HealthKitDebugHelper {
    
    /// Print comprehensive HealthKit status
    static func printStatus() {
        dlog("\n🔍 === HealthKit Debug Status ===")
        
        let manager = HealthKitManager.shared
        
        // Availability
        dlog("📱 Availability:")
        dlog("   - HealthKit Available: \(manager.isAvailable)")
        dlog("   - Sync Enabled: \(manager.isSyncEnabled)")
        if let lastSync = manager.lastSyncDate {
            dlog("   - Last Sync: \(lastSync)")
        } else {
            dlog("   - Last Sync: Never")
        }
        
        // Authorization Status
        dlog("\n🔐 Authorization Status:")
        
        if let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            let status = manager.authorizationStatus(for: weightType)
            dlog("   - Weight (Read): \(statusDescription(status))")
        }
        
        if let heightType = HKQuantityType.quantityType(forIdentifier: .height) {
            let status = manager.authorizationStatus(for: heightType)
            dlog("   - Height (Read): \(statusDescription(status))")
        }
        
        if let biologicalSexType = HKObjectType.characteristicType(forIdentifier: .biologicalSex) {
            let status = manager.authorizationStatus(for: biologicalSexType)
            dlog("   - Biological Sex (Read): \(statusDescription(status))")
        }
        
        if let dateOfBirthType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) {
            let status = manager.authorizationStatus(for: dateOfBirthType)
            dlog("   - Date of Birth (Read): \(statusDescription(status))")
        }
        
        if let calorieType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            let status = manager.authorizationStatus(for: calorieType)
            dlog("   - Dietary Energy (Write): \(statusDescription(status))")
        }
        
        if let proteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            let status = manager.authorizationStatus(for: proteinType)
            dlog("   - Protein (Write): \(statusDescription(status))")
        }
        
        dlog("\n================================\n")
    }
    
    /// Test reading all health data
    static func testReadAllData() async {
        dlog("\n🧪 === Testing HealthKit Read ===")
        
        let manager = HealthKitManager.shared
        
        do {
            let (weight, height, gender, age) = try await manager.readAllHealthData()
            
            dlog("📊 Read Results:")
            if let weight = weight {
                dlog("   ✅ Weight: \(weight) kg")
            } else {
                dlog("   ❌ Weight: Not available")
            }
            
            if let height = height {
                dlog("   ✅ Height: \(height) cm")
            } else {
                dlog("   ❌ Height: Not available")
            }
            
            if let gender = gender {
                dlog("   ✅ Gender: \(gender)")
            } else {
                dlog("   ❌ Gender: Not available")
            }
            
            if let age = age {
                dlog("   ✅ Age: \(age) years")
            } else {
                dlog("   ❌ Age: Not available")
            }
            
        } catch {
            dlog("   ❌ Error: \(error.localizedDescription)")
        }
        
        dlog("================================\n")
    }
    
    /// Test writing sample nutrition data
    static func testWriteNutritionData() async {
        dlog("\n🧪 === Testing HealthKit Write ===")
        
        let manager = HealthKitManager.shared
        
        // Write test data for today
        let testCalories = 500
        let testProtein = 30.0
        let testCarbs = 50.0
        let testFat = 20.0
        
        dlog("📝 Writing test data:")
        dlog("   - Calories: \(testCalories) kcal")
        dlog("   - Protein: \(testProtein) g")
        dlog("   - Carbs: \(testCarbs) g")
        dlog("   - Fat: \(testFat) g")
        
        do {
            try await manager.writeNutritionData(
                calories: testCalories,
                protein: testProtein,
                carbs: testCarbs,
                fat: testFat,
                date: Date(),
                entryId: "test-entry-\(UUID().uuidString)"
            )
            dlog("   ✅ Successfully wrote to HealthKit")
            dlog("   📱 Check Health app > Nutrition to verify")
        } catch {
            dlog("   ❌ Error: \(error.localizedDescription)")
        }
        
        dlog("================================\n")
    }
    
    /// Check what data exists in HealthKit for today
    static func checkTodayNutritionData() async {
        dlog("\n🔍 === Checking Today's Nutrition Data ===")
        
        guard let healthStore = HealthKitManager.shared.healthStore else {
            dlog("   ❌ HealthKit not available")
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        // Check calories
        if let calorieType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            let query = HKSampleQuery(
                sampleType: calorieType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    dlog("   ❌ Error reading calories: \(error.localizedDescription)")
                    return
                }
                
                if let samples = samples as? [HKQuantitySample], !samples.isEmpty {
                    let totalCalories = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .kilocalorie()) }
                    dlog("   ✅ Calories: \(Int(totalCalories)) kcal (\(samples.count) samples)")
                } else {
                    dlog("   ❌ Calories: No data found")
                }
            }
            healthStore.execute(query)
        }
        
        // Check protein
        if let proteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            let query = HKSampleQuery(
                sampleType: proteinType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    dlog("   ❌ Error reading protein: \(error.localizedDescription)")
                    return
                }
                
                if let samples = samples as? [HKQuantitySample], !samples.isEmpty {
                    let totalProtein = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .gram()) }
                    dlog("   ✅ Protein: \(totalProtein) g (\(samples.count) samples)")
                } else {
                    dlog("   ❌ Protein: No data found")
                }
            }
            healthStore.execute(query)
        }
        
        dlog("================================\n")
    }
    
    // MARK: - Helper Methods
    
    private static func statusDescription(_ status: HKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not Determined"
        case .sharingDenied:
            return "Denied"
        case .sharingAuthorized:
            return "Authorized"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Debug Commands for Xcode Console

/// Use these commands in Xcode debugger console:
///
/// Print HealthKit status:
/// ```
/// po HealthKitDebugHelper.printStatus()
/// ```
///
/// Test reading health data:
/// ```
/// po Task { await HealthKitDebugHelper.testReadAllData() }
/// ```
///
/// Test writing nutrition data:
/// ```
/// po Task { await HealthKitDebugHelper.testWriteNutritionData() }
/// ```
///
/// Check today's nutrition data:
/// ```
/// po Task { await HealthKitDebugHelper.checkTodayNutritionData() }
/// ```

#endif





