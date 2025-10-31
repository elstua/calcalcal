import Foundation

struct Configuration {
    static let apiURL: String = {
        #if DEBUG
        if let s = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String, !s.isEmpty {
            return s
        }
        return "http://localhost:3000"  // Local development
        #else
        return Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String ?? "https://calycal-app-egy2b.ondigitalocean.app"
        #endif
    }()
    
    // Legacy property name for backward compatibility during migration
    static var supabaseURL: String {
        return apiURL
    }
    
    static let appleClientId = "stua.calcalcal" // Your actual bundle identifier
}