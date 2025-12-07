import Foundation

/// Container for all data collected during onboarding.
/// This struct is persisted to UserDefaults so returning users see their previous selections.
///
/// All fields are optional because:
/// 1. User might skip steps
/// 2. Data is collected progressively across multiple screens
/// 3. We want to show empty fields for new users, pre-filled for returning users
struct OnboardingData: Codable, Equatable {
    // MARK: - Health Data (from HealthData step)
    
    /// User's current weight in kilograms
    var weightKg: Double?
    
    /// User's height in centimeters
    var heightCm: Double?
    
    /// User's age in years
    var age: Int?
    
    /// User's biological gender for TDEE calculation
    /// Values: "male", "female", "other"
    var gender: String?
    
    // MARK: - Activity Level (from ActivityLevel step)
    
    /// User's activity level for calorie calculation
    /// Values: "small", "moderate", "active"
    var activityLevel: String?
    
    // MARK: - Goals (from Goals step)
    
    /// User's target weight in kilograms
    var targetWeightKg: Double?
    
    /// Calculated daily calorie goal based on health data
    /// This is auto-calculated but can be manually overridden
    var calorieGoal: Int?
    
    // MARK: - Unit Preferences
    
    /// Preferred weight unit: "kg" or "lbs"
    var weightUnit: String?
    
    /// Preferred height unit: "cm" or "in"
    var heightUnit: String?
    
    // MARK: - HealthKit (for future iterations)
    
    /// Whether user has authorized HealthKit access
    var healthKitAuthorized: Bool?
    
    // MARK: - Initialization
    
    /// Create empty OnboardingData for new users
    init() {}
    
    /// Create OnboardingData with all fields (used for testing/debugging)
    init(
        weightKg: Double? = nil,
        heightCm: Double? = nil,
        age: Int? = nil,
        gender: String? = nil,
        activityLevel: String? = nil,
        targetWeightKg: Double? = nil,
        calorieGoal: Int? = nil,
        weightUnit: String? = nil,
        heightUnit: String? = nil,
        healthKitAuthorized: Bool? = nil
    ) {
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.age = age
        self.gender = gender
        self.activityLevel = activityLevel
        self.targetWeightKg = targetWeightKg
        self.calorieGoal = calorieGoal
        self.weightUnit = weightUnit
        self.heightUnit = heightUnit
        self.healthKitAuthorized = healthKitAuthorized
    }
    
    // MARK: - Computed Properties
    
    /// Check if we have enough data to calculate TDEE
    var hasMinimumHealthData: Bool {
        weightKg != nil && heightCm != nil && age != nil && gender != nil
    }
    
    /// Check if all health-related fields are filled
    var hasCompleteHealthData: Bool {
        hasMinimumHealthData && activityLevel != nil
    }
    
    /// Weight converted to pounds (for display when using imperial units)
    var weightLbs: Double? {
        guard let kg = weightKg else { return nil }
        return kg * 2.20462
    }
    
    /// Height converted to inches (for display when using imperial units)
    var heightInches: Double? {
        guard let cm = heightCm else { return nil }
        return cm / 2.54
    }
    
    /// Target weight converted to pounds
    var targetWeightLbs: Double? {
        guard let kg = targetWeightKg else { return nil }
        return kg * 2.20462
    }
    
    // MARK: - Helper Methods
    
    /// Calculate estimated daily calorie goal using Mifflin-St Jeor equation
    /// This matches the backend calculation for consistency
    func calculateCalorieGoal() -> Int? {
        guard let weight = weightKg,
              let height = heightCm,
              let userAge = age,
              let userGender = gender else {
            return nil
        }
        
        // Mifflin-St Jeor Equation for BMR
        var bmr: Double
        if userGender == "male" {
            bmr = 10 * weight + 6.25 * height - 5 * Double(userAge) + 5
        } else {
            bmr = 10 * weight + 6.25 * height - 5 * Double(userAge) - 161
        }
        
        // Activity multiplier
        let multiplier: Double
        switch activityLevel {
        case "small":
            multiplier = 1.2
        case "moderate":
            multiplier = 1.55
        case "active":
            multiplier = 1.725
        default:
            multiplier = 1.375 // Default to lightly active
        }
        
        return Int(bmr * multiplier)
    }
    
    /// Merge data from another OnboardingData, preferring non-nil values from the other
    /// Used when syncing with backend data
    mutating func merge(with other: OnboardingData) {
        if let value = other.weightKg { self.weightKg = value }
        if let value = other.heightCm { self.heightCm = value }
        if let value = other.age { self.age = value }
        if let value = other.gender { self.gender = value }
        if let value = other.activityLevel { self.activityLevel = value }
        if let value = other.targetWeightKg { self.targetWeightKg = value }
        if let value = other.calorieGoal { self.calorieGoal = value }
        if let value = other.weightUnit { self.weightUnit = value }
        if let value = other.heightUnit { self.heightUnit = value }
        if let value = other.healthKitAuthorized { self.healthKitAuthorized = value }
    }
}

// MARK: - Activity Level Enum

/// Strongly-typed activity levels for better type safety
enum ActivityLevel: String, Codable, CaseIterable {
    case small = "small"
    case moderate = "moderate"
    case active = "active"
    
    var displayName: String {
        switch self {
        case .small:
            return "Small"
        case .moderate:
            return "Moderate"
        case .active:
            return "Active"
        }
    }
    
    var description: String {
        switch self {
        case .small:
            return "Little or no exercise, desk job"
        case .moderate:
            return "Light exercise 1-3 days/week"
        case .active:
            return "Hard exercise 6-7 days/week"
        }
    }
    
    var multiplier: Double {
        switch self {
        case .small:
            return 1.2
        case .moderate:
            return 1.55
        case .active:
            return 1.725
        }
    }
}

// MARK: - Gender Enum

/// Strongly-typed gender options for health calculations
enum Gender: String, Codable, CaseIterable {
    case male = "male"
    case female = "female"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .male:
            return "Male"
        case .female:
            return "Female"
        case .other:
            return "Other"
        }
    }
}

