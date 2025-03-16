import Foundation
import UIKit

class CalorieCalculationService {
    static let shared = CalorieCalculationService()
    
    // Keep track of recent calculations to avoid redundant calls
    private var calculationCache: [String: Int] = [:]
    
    private init() {}
    
    // Calculate calories for text
    func calculateCaloriesFor(text: String, completion: @escaping (Int) -> Void) {
        // Check cache first
        if let cachedValue = calculationCache[text] {
            completion(cachedValue)
            return
        }
        
        // In a real app, this would call your backend API
        // For now, we'll use a mock implementation
        mockCalculateCalories(for: text) { [weak self] calories in
            // Cache the result
            self?.calculationCache[text] = calories
            completion(calories)
        }
    }
    
    // Calculate calories for an image
    func calculateCaloriesFor(image: UIImage, completion: @escaping (Int) -> Void) {
        // In a real app, this would send the image to your backend
        // For now, we'll use a mock implementation
        
        // Convert image to a hash for caching
        let imageHash = String(image.hashValue)
        
        // Check cache first
        if let cachedValue = calculationCache[imageHash] {
            completion(cachedValue)
            return
        }
        
        // Mock calculation with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            // Generate a realistic calorie count for an image
            let calories = Int.random(in: 200...800)
            
            // Cache the result
            self?.calculationCache[imageHash] = calories
            completion(calories)
        }
    }
    
    // MARK: - Mock Implementation
    
    private func mockCalculateCalories(for text: String, completion: @escaping (Int) -> Void) {
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Parse the text to identify potential food items
            let words = text.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            
            // Base calories on text length for more realistic values
            let baseCalories = max(100, min(text.count * 5, 1500))
            
            // Add some randomness but keep it within reasonable range
            let calories = baseCalories + Int.random(in: -50...50)
            
            completion(calories)
        }
    }
    
    // Clear the cache
    func clearCache() {
        calculationCache.removeAll()
    }
}