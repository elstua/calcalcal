import Foundation

struct Configuration {
    static let apiURL: String = {
        #if DEBUG
        if let s = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String, !s.isEmpty {
            print("🔧 Configuration: Using API_URL from Info.plist: \(s)")
            return s
        }
        let localURL = "http://localhost:3000"
        print("🔧 Configuration: Using default local URL: \(localURL)")
        return localURL  // Local development
        #else
        // Try to read from Info.plist first, but hardcode production URL as fallback
        // This ensures the app works even if Info.plist values aren't accessible in release builds
        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String, !plistURL.isEmpty {
            return plistURL
        }
        // Hardcoded production URL for release builds (TestFlight/App Store)
        return "https://calycal-app-egy2b.ondigitalocean.app"
        #endif
    }()
    
    static let appleClientId = "stua.calcalcal" // Your actual bundle identifier
}