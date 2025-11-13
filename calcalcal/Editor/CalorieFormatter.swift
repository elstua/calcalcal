import Foundation

struct CalorieFormatter {
    /// Format calories from String? (e.g., metadata.calorieData) to "123 kcal" or "…"
    static func format(_ caloriesString: String?) -> String {
        guard let caloriesString = caloriesString, !caloriesString.isEmpty else {
            return "…"
        }
        if let value = Int(caloriesString) {
            return "\(value) kcal"
        }
        // Try to parse decimal representations like "120.0"
        if let doubleValue = Double(caloriesString) {
            let rounded = Int(doubleValue.rounded())
            return "\(rounded) kcal"
        }
        // Non-numeric strings fallback to placeholder for safety
        return "…"
    }
    
    /// Format calories from Int? to "123 kcal" or "…"
    static func format(_ calories: Int?) -> String {
        guard let calories = calories else { return "…" }
        return "\(calories) kcal"
    }
}

