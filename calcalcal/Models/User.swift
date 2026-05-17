import Foundation

/// Adherence corridor for a macro/calorie goal: min/max grams (or kcal).
/// Provided by the backend; pure derived data from goal values.
struct MacroRange: Codable, Equatable {
    let min: Double
    let max: Double
}

struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let name: String?
    let appleId: String?
    let googleId: String?
    let dailyCalorieGoal: Int?
    let dailyProteinGoal: Double?
    let dailyFatGoal: Double?
    let dailyCarbGoal: Double?

    /// Adherence corridor (min/max) derived from the goals — sent by the backend.
    /// Used in UI to show "100–130 g" beneath each macro value.
    let dailyCalorieRange: MacroRange?
    let dailyProteinRange: MacroRange?
    let dailyFatRange: MacroRange?
    let dailyCarbRange: MacroRange?
    let units: String?
    let timezoneOffset: Int?
    let createdAt: Date?
    let updatedAt: Date?
    
    // MARK: - Health & Profile Fields (for onboarding)
    
    /// User's current weight in kilograms
    let weightKg: Double?
    
    /// User's height in centimeters
    let heightCm: Double?
    
    /// User's age in years
    let age: Int?
    
    /// User's activity level: "sedentary", "light", "moderate", "active", "very_active"
    let activityLevel: String?
    
    /// User's target weight in kilograms
    let targetWeightKg: Double?
    
    /// User's biological gender: "male", "female", "other"
    let gender: String?
    
    /// Preferred weight unit: "kg" or "lbs"
    let weightUnit: String?
    
    /// Preferred height unit: "cm" or "in"
    let heightUnit: String?
    
    /// Whether user has completed onboarding
    let onboardingCompleted: Bool?
    
    // MARK: - Temporary Account Fields
    
    /// Whether this is a temporary (non-OAuth) account
    let isTemporary: Bool?
    
    /// Device ID for temporary accounts
    let deviceId: String?
    
    /// How the account was created: "apple", "google", or "temporary"
    let createdVia: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email = "email"
        case name = "name"
        case appleId = "apple_id"
        case googleId = "google_id"
        case dailyCalorieGoal = "daily_calorie_goal"
        case dailyProteinGoal = "daily_protein_goal"
        case dailyFatGoal = "daily_fat_goal"
        case dailyCarbGoal = "daily_carb_goal"
        case dailyCalorieRange = "daily_calorie_range"
        case dailyProteinRange = "daily_protein_range"
        case dailyFatRange = "daily_fat_range"
        case dailyCarbRange = "daily_carb_range"
        case units
        case timezoneOffset = "timezone_offset"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        // Health & profile fields
        case weightKg = "weight_kg"
        case heightCm = "height_cm"
        case age
        case activityLevel = "activity_level"
        case targetWeightKg = "target_weight_kg"
        case gender
        case weightUnit = "weight_unit"
        case heightUnit = "height_unit"
        case onboardingCompleted = "onboarding_completed"
        // Temporary account fields
        case isTemporary = "is_temporary"
        case deviceId = "device_id"
        case createdVia = "created_via"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.appleId = try container.decodeIfPresent(String.self, forKey: .appleId)
        self.googleId = try container.decodeIfPresent(String.self, forKey: .googleId)
        self.dailyCalorieGoal = try container.decodeIfPresent(Int.self, forKey: .dailyCalorieGoal)
        self.dailyProteinGoal = try User.decodeLenientDouble(container: container, forKey: .dailyProteinGoal)
        self.dailyFatGoal = try User.decodeLenientDouble(container: container, forKey: .dailyFatGoal)
        self.dailyCarbGoal = try User.decodeLenientDouble(container: container, forKey: .dailyCarbGoal)
        self.dailyCalorieRange = try container.decodeIfPresent(MacroRange.self, forKey: .dailyCalorieRange)
        self.dailyProteinRange = try container.decodeIfPresent(MacroRange.self, forKey: .dailyProteinRange)
        self.dailyFatRange = try container.decodeIfPresent(MacroRange.self, forKey: .dailyFatRange)
        self.dailyCarbRange = try container.decodeIfPresent(MacroRange.self, forKey: .dailyCarbRange)
        self.units = try container.decodeIfPresent(String.self, forKey: .units)
        self.timezoneOffset = try container.decodeIfPresent(Int.self, forKey: .timezoneOffset)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        // Health & profile fields
        self.weightKg = try User.decodeLenientDouble(container: container, forKey: .weightKg)
        self.heightCm = try User.decodeLenientDouble(container: container, forKey: .heightCm)
        self.age = try container.decodeIfPresent(Int.self, forKey: .age)
        self.activityLevel = try container.decodeIfPresent(String.self, forKey: .activityLevel)
        self.targetWeightKg = try User.decodeLenientDouble(container: container, forKey: .targetWeightKg)
        self.gender = try container.decodeIfPresent(String.self, forKey: .gender)
        self.weightUnit = try container.decodeIfPresent(String.self, forKey: .weightUnit)
        self.heightUnit = try container.decodeIfPresent(String.self, forKey: .heightUnit)
        self.onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted)
        // Temporary account fields
        self.isTemporary = try container.decodeIfPresent(Bool.self, forKey: .isTemporary)
        self.deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
        self.createdVia = try container.decodeIfPresent(String.self, forKey: .createdVia)
    }

    private static func decodeLenientDouble(container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Double? {
        if let number = try? container.decode(Double.self, forKey: key) {
            return number
        }
        if let stringValue = try? container.decode(String.self, forKey: key) {
            return Double(stringValue)
        }
        return nil
    }
}

// MARK: - OnboardingData Conversion

extension User {
    /// Convert User's health fields to OnboardingData for pre-filling
    /// Used when a returning user needs to see their previously entered data
    func toOnboardingData() -> OnboardingData {
        OnboardingData(
            weightKg: weightKg,
            heightCm: heightCm,
            age: age,
            gender: gender,
            activityLevel: activityLevel,
            targetWeightKg: targetWeightKg,
            calorieGoal: dailyCalorieGoal,
            weightUnit: weightUnit,
            heightUnit: heightUnit
        )
    }
    
    /// Check if user has any health data filled in
    var hasHealthData: Bool {
        weightKg != nil || heightCm != nil || age != nil || gender != nil
    }
} 
