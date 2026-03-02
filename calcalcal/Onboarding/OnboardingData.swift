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
    /// Values: "sedentary", "light", "moderate", "active", "very_active"
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
    /// with Legion-adjusted activity multipliers and goal-based deficit/surplus.
    /// This matches the backend calculation for consistency.
    func calculateCalorieGoal() -> Int? {
        guard let weight = weightKg,
              let height = heightCm,
              let userAge = age,
              let userGender = gender else {
            return nil
        }

        // Mifflin-St Jeor Equation for BMR
        let bmr: Double
        if userGender == "male" {
            bmr = 10 * weight + 6.25 * height - 5 * Double(userAge) + 5
        } else if userGender == "female" {
            bmr = 10 * weight + 6.25 * height - 5 * Double(userAge) - 161
        } else {
            // "other" — average of male and female
            let maleBMR = 10 * weight + 6.25 * height - 5 * Double(userAge) + 5
            let femaleBMR = 10 * weight + 6.25 * height - 5 * Double(userAge) - 161
            bmr = (maleBMR + femaleBMR) / 2
        }

        // Activity multiplier (Legion-adjusted)
        let multiplier: Double
        if let level = ActivityLevel(rawValue: activityLevel ?? "") {
            multiplier = level.multiplier
        } else {
            multiplier = 1.35 // Default to light
        }

        let tdee = bmr * multiplier

        // Goal-based adjustment (deficit/surplus)
        var goalMultiplier = 1.0
        if let target = targetWeightKg {
            if target < weight {
                goalMultiplier = 0.80 // -20% for weight loss
            } else if target > weight {
                goalMultiplier = 1.10 // +10% for weight gain
            }
        }

        var goal = Int(tdee * goalMultiplier)

        // Safety floor
        let minCalories: Int
        if userGender == "female" {
            minCalories = 1200
        } else if userGender == "male" {
            minCalories = 1500
        } else {
            minCalories = 1350
        }
        goal = max(goal, minCalories)

        return goal
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

/// Strongly-typed activity levels with Legion-adjusted multipliers.
/// These multipliers are lower than classic Harris-Benedict values to
/// better reflect real-world energy expenditure.
enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary = "sedentary"
    case light = "light"
    case moderate = "moderate"
    case active = "active"
    case veryActive = "very_active"

    /// Handle backward compatibility with old "small" value
    init?(rawValue: String) {
        switch rawValue {
        case "sedentary": self = .sedentary
        case "light": self = .light
        case "moderate": self = .moderate
        case "active": self = .active
        case "very_active": self = .veryActive
        case "small": self = .sedentary // Legacy mapping
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .sedentary:
            return "Sedentary"
        case .light:
            return "Light"
        case .moderate:
            return "Moderate"
        case .active:
            return "Active"
        case .veryActive:
            return "Very Active"
        }
    }

    var description: String {
        switch self {
        case .sedentary:
            return "Little or no exercise, desk job"
        case .light:
            return "Light exercise 1-3 days/week"
        case .moderate:
            return "Moderate exercise 3-5 days/week"
        case .active:
            return "Hard exercise 6-7 days/week"
        case .veryActive:
            return "Intense exercise or physical job"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary:
            return 1.15
        case .light:
            return 1.35
        case .moderate:
            return 1.50
        case .active:
            return 1.60
        case .veryActive:
            return 1.80
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
