import Foundation
import HealthKit

#if DEBUG
/// Debug helper for testing HealthKit integration
/// Only available in DEBUG builds
struct HealthKitDebugHelper {
    
    /// Print comprehensive HealthKit status
    static func printStatus() {
        print("\n🔍 === HealthKit Debug Status ===")
        
        let manager = HealthKitManager.shared
        
        // Availability
        print("📱 Availability:")
        print("   - HealthKit Available: \(manager.isAvailable)")
        print("   - Sync Enabled: \(manager.isSyncEnabled)")
        if let lastSync = manager.lastSyncDate {
            print("   - Last Sync: \(lastSync)")
        } else {
            print("   - Last Sync: Never")
        }
        
        // Authorization Status
        print("\n🔐 Authorization Status:")
        
        if let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            let status = manager.authorizationStatus(for: weightType)
            print("   - Weight (Read): \(statusDescription(status))")
        }
        
        if let heightType = HKQuantityType.quantityType(forIdentifier: .height) {
            let status = manager.authorizationStatus(for: heightType)
            print("   - Height (Read): \(statusDescription(status))")
        }
        
        if let biologicalSexType = HKObjectType.characteristicType(forIdentifier: .biologicalSex) {
            let status = manager.authorizationStatus(for: biologicalSexType)
            print("   - Biological Sex (Read): \(statusDescription(status))")
        }
        
        if let dateOfBirthType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) {
            let status = manager.authorizationStatus(for: dateOfBirthType)
            print("   - Date of Birth (Read): \(statusDescription(status))")
        }
        
        if let calorieType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            let status = manager.authorizationStatus(for: calorieType)
            print("   - Dietary Energy (Write): \(statusDescription(status))")
        }
        
        if let proteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            let status = manager.authorizationStatus(for: proteinType)
            print("   - Protein (Write): \(statusDescription(status))")
        }
        
        print("\n================================\n")
    }
    
    /// Test reading all health data
    static func testReadAllData() async {
        print("\n🧪 === Testing HealthKit Read ===")
        
        let manager = HealthKitManager.shared
        
        do {
            let (weight, height, gender, age) = try await manager.readAllHealthData()
            
            print("📊 Read Results:")
            if let weight = weight {
                print("   ✅ Weight: \(weight) kg")
            } else {
                print("   ❌ Weight: Not available")
            }
            
            if let height = height {
                print("   ✅ Height: \(height) cm")
            } else {
                print("   ❌ Height: Not available")
            }
            
            if let gender = gender {
                print("   ✅ Gender: \(gender)")
            } else {
                print("   ❌ Gender: Not available")
            }
            
            if let age = age {
                print("   ✅ Age: \(age) years")
            } else {
                print("   ❌ Age: Not available")
            }
            
        } catch {
            print("   ❌ Error: \(error.localizedDescription)")
        }
        
        print("================================\n")
    }
    
    /// Test writing sample nutrition data
    static func testWriteNutritionData() async {
        print("\n🧪 === Testing HealthKit Write ===")
        
        let manager = HealthKitManager.shared
        
        // Write test data for today
        let testCalories = 500
        let testProtein = 30.0
        let testCarbs = 50.0
        let testFat = 20.0
        
        print("📝 Writing test data:")
        print("   - Calories: \(testCalories) kcal")
        print("   - Protein: \(testProtein) g")
        print("   - Carbs: \(testCarbs) g")
        print("   - Fat: \(testFat) g")
        
        do {
            try await manager.writeNutritionData(
                calories: testCalories,
                protein: testProtein,
                carbs: testCarbs,
                fat: testFat,
                date: Date(),
                entryId: "test-entry-\(UUID().uuidString)"
            )
            print("   ✅ Successfully wrote to HealthKit")
            print("   📱 Check Health app > Nutrition to verify")
        } catch {
            print("   ❌ Error: \(error.localizedDescription)")
        }
        
        print("================================\n")
    }
    
    /// Check what data exists in HealthKit for today
    static func checkTodayNutritionData() async {
        print("\n🔍 === Checking Today's Nutrition Data ===")
        
        guard let healthStore = HealthKitManager.shared.healthStore else {
            print("   ❌ HealthKit not available")
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
                    print("   ❌ Error reading calories: \(error.localizedDescription)")
                    return
                }
                
                if let samples = samples as? [HKQuantitySample], !samples.isEmpty {
                    let totalCalories = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .kilocalorie()) }
                    print("   ✅ Calories: \(Int(totalCalories)) kcal (\(samples.count) samples)")
                } else {
                    print("   ❌ Calories: No data found")
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
                    print("   ❌ Error reading protein: \(error.localizedDescription)")
                    return
                }
                
                if let samples = samples as? [HKQuantitySample], !samples.isEmpty {
                    let totalProtein = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .gram()) }
                    print("   ✅ Protein: \(totalProtein) g (\(samples.count) samples)")
                } else {
                    print("   ❌ Protein: No data found")
                }
            }
            healthStore.execute(query)
        }
        
        print("================================\n")
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


