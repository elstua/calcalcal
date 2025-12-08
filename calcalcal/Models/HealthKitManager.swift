import Foundation
import HealthKit

// MARK: - HealthKit Error Types

/// Custom errors for HealthKit operations
enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case dataNotAvailable
    case invalidData
    case writeFailed(String)
    case readFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .dataNotAvailable:
            return "The requested health data is not available"
        case .invalidData:
            return "Invalid health data"
        case .writeFailed(let reason):
            return "Failed to write to HealthKit: \(reason)"
        case .readFailed(let reason):
            return "Failed to read from HealthKit: \(reason)"
        }
    }
}

// MARK: - HealthKit Manager

/// Singleton class managing all HealthKit operations for the app.
/// Handles reading health data (weight, height, biological sex, date of birth)
/// and writing nutrition data (calories, protein, carbs, fat).
final class HealthKitManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = HealthKitManager()
    
    // MARK: - Properties
    
    /// HealthKit store instance
    /// Internal access for debug helpers in the same module
    internal let healthStore: HKHealthStore?
    
    /// Whether HealthKit is available on this device
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    /// Published property to track authorization state
    @Published private(set) var isAuthorized: Bool = false
    
    /// UserDefaults key for tracking HealthKit sync preference
    private static let healthKitSyncEnabledKey = "healthkit_sync_enabled"
    private static let lastHealthKitSyncKey = "healthkit_last_sync"
    
    /// Whether automatic HealthKit sync is enabled
    var isSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.healthKitSyncEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.healthKitSyncEnabledKey) }
    }
    
    /// Last sync timestamp
    var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: Self.lastHealthKitSyncKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastHealthKitSyncKey) }
    }
    
    // MARK: - Data Types
    
    /// Types we want to READ from HealthKit
    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        
        // Quantity types (weight, height)
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        if let height = HKObjectType.quantityType(forIdentifier: .height) {
            types.insert(height)
        }
        
        // Characteristic types (biological sex, date of birth)
        if let biologicalSex = HKObjectType.characteristicType(forIdentifier: .biologicalSex) {
            types.insert(biologicalSex)
        }
        if let dateOfBirth = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) {
            types.insert(dateOfBirth)
        }
        
        return types
    }
    
    /// Types we want to WRITE to HealthKit
    private var writeTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        
        // Dietary types (calories, protein, carbs, fat)
        if let dietaryEnergy = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            types.insert(dietaryEnergy)
        }
        if let protein = HKObjectType.quantityType(forIdentifier: .dietaryProtein) {
            types.insert(protein)
        }
        if let carbs = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            types.insert(carbs)
        }
        if let fat = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal) {
            types.insert(fat)
        }
        
        return types
    }
    
    // MARK: - Initialization
    
    private init() {
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        } else {
            healthStore = nil
        }
    }
    
    // MARK: - Authorization
    
    /// Request read permissions for health data.
    /// This automatically shows Apple's standard HealthKit permission sheet.
    /// - Returns: `true` if authorization was granted (at least partially)
    @MainActor
    func requestReadPermissions() async throws -> Bool {
        guard let healthStore = healthStore else {
            throw HealthKitError.notAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
                if let error = error {
                    print("[HealthKit] Read authorization error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                print("[HealthKit] Read authorization result: \(success)")
                Task { @MainActor in
                    self.isAuthorized = success
                    if success {
                        self.isSyncEnabled = true
                    }
                }
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Request write permissions for nutrition data.
    /// This automatically shows Apple's standard HealthKit permission sheet.
    /// - Returns: `true` if authorization was granted
    @MainActor
    func requestWritePermissions() async throws -> Bool {
        guard let healthStore = healthStore else {
            throw HealthKitError.notAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: writeTypes, read: nil) { success, error in
                if let error = error {
                    print("[HealthKit] Write authorization error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                print("[HealthKit] Write authorization result: \(success)")
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Request both read and write permissions at once.
    /// This shows a single permission sheet with all requested data types.
    /// - Returns: `true` if authorization was granted
    @MainActor
    func requestAllPermissions() async throws -> Bool {
        guard let healthStore = healthStore else {
            throw HealthKitError.notAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
                if let error = error {
                    print("[HealthKit] Authorization error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                print("[HealthKit] Authorization result: \(success)")
                Task { @MainActor in
                    self.isAuthorized = success
                    if success {
                        self.isSyncEnabled = true
                    }
                }
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Check if a specific type is authorized for reading
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        guard let healthStore = healthStore else {
            return .notDetermined
        }
        return healthStore.authorizationStatus(for: type)
    }
    
    // MARK: - Reading Data
    
    /// Read the most recent weight from HealthKit
    /// - Returns: Weight in kilograms, or nil if not available
    func readLatestWeight() async throws -> Double? {
        guard let healthStore = healthStore else {
            throw HealthKitError.notAvailable
        }
        
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitError.dataNotAvailable
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    print("[HealthKit] Error reading weight: \(error.localizedDescription)")
                    continuation.resume(throwing: HealthKitError.readFailed(error.localizedDescription))
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    print("[HealthKit] No weight data available")
                    continuation.resume(returning: nil)
                    return
                }
                
                let weightKg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                print("[HealthKit] Read weight: \(weightKg) kg")
                continuation.resume(returning: weightKg)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Read the most recent height from HealthKit
    /// - Returns: Height in centimeters, or nil if not available
    func readLatestHeight() async throws -> Double? {
        guard let healthStore = healthStore else {
            throw HealthKitError.notAvailable
        }
        
        guard let heightType = HKQuantityType.quantityType(forIdentifier: .height) else {
            throw HealthKitError.dataNotAvailable
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    print("[HealthKit] Error reading height: \(error.localizedDescription)")
                    continuation.resume(throwing: HealthKitError.readFailed(error.localizedDescription))
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    print("[HealthKit] No height data available")
                    continuation.resume(returning: nil)
                    return
                }
                
                let heightCm = sample.quantity.doubleValue(for: .meterUnit(with: .centi))
                print("[HealthKit] Read height: \(heightCm) cm")
                continuation.resume(returning: heightCm)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Read biological sex from HealthKit
    /// - Returns: Biological sex, or nil if not set
    func readBiologicalSex() throws -> HKBiologicalSex? {
        guard let healthStore = healthStore else {
            throw HealthKitError.notAvailable
        }
        
        do {
            let biologicalSex = try healthStore.biologicalSex()
            print("[HealthKit] Read biological sex: \(biologicalSex.biologicalSex.rawValue)")
            return biologicalSex.biologicalSex
        } catch {
            print("[HealthKit] Error reading biological sex: \(error.localizedDescription)")
            // Return nil instead of throwing - biological sex might not be set
            return nil
        }
    }
    
    /// Read date of birth from HealthKit
    /// - Returns: Date components, or nil if not set
    func readDateOfBirth() throws -> DateComponents? {
        guard let healthStore = healthStore else {
            throw HealthKitError.notAvailable
        }
        
        do {
            let dateOfBirth = try healthStore.dateOfBirthComponents()
            print("[HealthKit] Read date of birth: \(dateOfBirth)")
            return dateOfBirth
        } catch {
            print("[HealthKit] Error reading date of birth: \(error.localizedDescription)")
            // Return nil instead of throwing - date of birth might not be set
            return nil
        }
    }
    
    /// Calculate age from date of birth
    /// - Returns: Age in years, or nil if date of birth is not available
    func calculateAge() throws -> Int? {
        guard let dateOfBirth = try readDateOfBirth(),
              let birthDate = Calendar.current.date(from: dateOfBirth) else {
            return nil
        }
        
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
        print("[HealthKit] Calculated age: \(age ?? 0)")
        return age
    }
    
    /// Convert HKBiologicalSex to gender string for the app
    /// - Parameter biologicalSex: The biological sex from HealthKit
    /// - Returns: Gender string ("male", "female", "other") or nil
    func genderString(from biologicalSex: HKBiologicalSex) -> String? {
        switch biologicalSex {
        case .male:
            return "male"
        case .female:
            return "female"
        case .other:
            return "other"
        case .notSet:
            return nil
        @unknown default:
            return nil
        }
    }
    
    // MARK: - Writing Data
    
    /// Write nutrition data to HealthKit for a specific date
    /// - Parameters:
    ///   - calories: Calorie intake in kcal
    ///   - protein: Protein intake in grams
    ///   - carbs: Carbohydrate intake in grams
    ///   - fat: Fat intake in grams
    ///   - date: The date for this nutrition data (diary entry date)
    ///   - entryId: Optional diary entry ID for metadata
    func writeNutritionData(
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        date: Date,
        entryId: String? = nil
    ) async throws {
        guard let healthStore = healthStore else {
            throw HealthKitError.notAvailable
        }
        
        // Create samples for the day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw HealthKitError.invalidData
        }
        
        // Build metadata
        var metadata: [String: Any] = [
            HKMetadataKeyWasUserEntered: false // Indicates this came from our app, not manual entry
        ]
        if let entryId = entryId {
            metadata["CalycalDiaryEntryId"] = entryId
        }
        
        var samplesToSave: [HKQuantitySample] = []
        
        // Calories
        if calories > 0, let calorieType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            let calorieQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: Double(calories))
            let calorieSample = HKQuantitySample(
                type: calorieType,
                quantity: calorieQuantity,
                start: startOfDay,
                end: endOfDay,
                metadata: metadata
            )
            samplesToSave.append(calorieSample)
        }
        
        // Protein
        if protein > 0, let proteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            let proteinQuantity = HKQuantity(unit: .gram(), doubleValue: protein)
            let proteinSample = HKQuantitySample(
                type: proteinType,
                quantity: proteinQuantity,
                start: startOfDay,
                end: endOfDay,
                metadata: metadata
            )
            samplesToSave.append(proteinSample)
        }
        
        // Carbs
        if carbs > 0, let carbsType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            let carbsQuantity = HKQuantity(unit: .gram(), doubleValue: carbs)
            let carbsSample = HKQuantitySample(
                type: carbsType,
                quantity: carbsQuantity,
                start: startOfDay,
                end: endOfDay,
                metadata: metadata
            )
            samplesToSave.append(carbsSample)
        }
        
        // Fat
        if fat > 0, let fatType = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) {
            let fatQuantity = HKQuantity(unit: .gram(), doubleValue: fat)
            let fatSample = HKQuantitySample(
                type: fatType,
                quantity: fatQuantity,
                start: startOfDay,
                end: endOfDay,
                metadata: metadata
            )
            samplesToSave.append(fatSample)
        }
        
        guard !samplesToSave.isEmpty else {
            print("[HealthKit] No nutrition data to save (all values are zero)")
            return
        }
        
        // Save all samples
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(samplesToSave) { success, error in
                if let error = error {
                    print("[HealthKit] Error saving nutrition data: \(error.localizedDescription)")
                    continuation.resume(throwing: HealthKitError.writeFailed(error.localizedDescription))
                    return
                }
                
                if success {
                    print("[HealthKit] Successfully saved nutrition data: \(calories) kcal, \(protein)g protein, \(carbs)g carbs, \(fat)g fat")
                    Task { @MainActor in
                        self.lastSyncDate = Date()
                    }
                }
                continuation.resume()
            }
        }
    }
    
    /// Delete nutrition samples for a specific date (to allow updates)
    /// - Parameter date: The date to delete nutrition data for
    func deleteNutritionData(for date: Date) async throws {
        guard let healthStore = healthStore else {
            throw HealthKitError.notAvailable
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw HealthKitError.invalidData
        }
        
        // Create predicate for the specific day and samples from our app
        let datePredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let sourcePredicate = HKQuery.predicateForObjects(from: .default())
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, sourcePredicate])
        
        let typesToDelete: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal
        ]
        
        for typeIdentifier in typesToDelete {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else {
                continue
            }
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                healthStore.deleteObjects(of: quantityType, predicate: predicate) { success, deletedCount, error in
                    if let error = error {
                        print("[HealthKit] Error deleting \(typeIdentifier): \(error.localizedDescription)")
                        continuation.resume(throwing: HealthKitError.writeFailed(error.localizedDescription))
                        return
                    }
                    print("[HealthKit] Deleted \(deletedCount) \(typeIdentifier) samples")
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Read all available health data at once
    /// - Returns: Tuple containing weight, height, gender, and age
    func readAllHealthData() async throws -> (weight: Double?, height: Double?, gender: String?, age: Int?) {
        let weight = try await readLatestWeight()
        let height = try await readLatestHeight()
        
        let biologicalSex = try readBiologicalSex()
        let gender = biologicalSex.flatMap { genderString(from: $0) }
        
        let age = try calculateAge()
        
        return (weight, height, gender, age)
    }
    
    /// Update last sync timestamp
    func markSynced() {
        lastSyncDate = Date()
    }
}

