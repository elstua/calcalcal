import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let name: String?
    let appleId: String?
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
        case dailyCalorieGoal = "daily_calorie_goal"
        case dailyProteinGoal = "daily_protein_goal"
        case dailyFatGoal = "daily_fat_goal"
        case dailyCarbGoal = "daily_carb_goal"
        case units
        case timezoneOffset = "timezone_offset"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
} 
