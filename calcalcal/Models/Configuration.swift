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
    
    // Google Sign-In Client ID
    // Get this from Google Cloud Console: https://console.cloud.google.com/apis/credentials
    // 1. Create a new OAuth 2.0 Client ID (iOS application type)
    // 2. Enter your bundle ID: stua.calcalcal
    // 3. Copy the Client ID here
    static let googleClientId: String = {
        // Try GIDClientID first (standard Google SDK key name)
        if let clientId = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String, !clientId.isEmpty {
            return clientId
        }
        // Fallback to GOOGLE_CLIENT_ID
        if let clientId = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String, !clientId.isEmpty {
            return clientId
        }
        // Hardcoded fallback
        return "719863771026-al64a24evjcndbtcn7395eqq1to8m5n2.apps.googleusercontent.com"
    }()
}
