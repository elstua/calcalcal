import Foundation

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
    let units: String?
    let timezoneOffset: Int?
    let createdAt: Date?
    let updatedAt: Date?
    
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
        case units
        case timezoneOffset = "timezone_offset"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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
        self.units = try container.decodeIfPresent(String.self, forKey: .units)
        self.timezoneOffset = try container.decodeIfPresent(Int.self, forKey: .timezoneOffset)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
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
