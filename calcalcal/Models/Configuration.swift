import Foundation

/// Application Configuration
/// 
/// This struct provides centralized access to all app configuration values.
/// API URLs are injected via build configuration files (xcconfig) and read from Info.plist.
///
/// Build Configurations:
/// - Debug: Uses local backend (http://localhost:3000)
/// - Release: Uses production backend (https://api.calcalcal.app)
/// - Staging: Can point to staging environment
///
/// To modify API URLs, edit the corresponding xcconfig file in the xcconfigs/ directory:
/// - xcconfigs/Debug.xcconfig
/// - xcconfigs/Release.xcconfig
/// - xcconfigs/Staging.xcconfig
struct Configuration {
    
    // MARK: - API URLs
    
    /// Fixes URLs from xcconfig that use single slash (http:/ instead of http://)
    /// This is needed because // starts a comment in xcconfig files
    private static func fixURLFromXCConfig(_ url: String) -> String {
        // Replace "http:/" (not followed by /) with "http://"
        // and "https:/" (not followed by /) with "https://"
        var fixed = url
        
        // Handle http:/ that should be http://
        if fixed.range(of: "http:/") != nil && !fixed.hasPrefix("http://") {
            fixed = fixed.replacingOccurrences(of: "http:/", with: "http://", options: .anchored)
        }
        // Handle https:/ that should be https://
        if fixed.range(of: "https:/") != nil && !fixed.hasPrefix("https://") {
            fixed = fixed.replacingOccurrences(of: "https:/", with: "https://", options: .anchored)
        }
        
        return fixed
    }
    
    /// Base URL for API calls (auth, diary, storage)
    /// 
    /// In DEBUG builds, defaults to localhost if not specified in Info.plist.
    /// In RELEASE builds, must be specified in Info.plist.
    /// 
    /// Note: xcconfig uses single slashes (http:/ instead of http://) because // starts a comment.
    /// The fixURLFromXCConfig function converts these to proper URLs.
    static let apiURL: String = {
        // First, try to read from Info.plist (injected via xcconfig)
        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String,
           !plistURL.isEmpty,
           !plistURL.hasPrefix("$") {  // Check that variable was expanded (not ${API_URL})
            let fixedURL = fixURLFromXCConfig(plistURL)
            dlog("🔧 Configuration: Using API_URL from Info.plist: \(fixedURL) (raw: \(plistURL))")
            return fixedURL
        }
        
        #if DEBUG
        let localURL = "http://localhost:3000"
        dlog("🔧 Configuration: Using default local URL: \(localURL)")
        return localURL
        #else
        // In release, this is a critical error
        fatalError("API_URL not configured in Info.plist for Release build")
        #endif
    }()
    
    /// Base URL for image/media assets (where uploads are served)
    /// Falls back to apiURL if not specified
    static let mediaBaseURL: String = {
        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "MEDIA_URL") as? String,
           !plistURL.isEmpty,
           !plistURL.hasPrefix("$") {
            return fixURLFromXCConfig(plistURL)
        }
        return apiURL
    }()
    
    // MARK: - Authentication
    
    /// Apple Sign-In Client ID (Bundle Identifier)
    static let appleClientId = "stua.calcalcal"
    
    /// Google Sign-In Client ID
    /// 
    /// Configuration priority:
    /// 1. GIDClientID from Info.plist (standard Google SDK key)
    /// 2. GOOGLE_CLIENT_ID from Info.plist (custom key)
    /// 3. Hardcoded fallback (for development)
    static let googleClientId: String = {
        // Try GIDClientID first (standard Google SDK key name)
        if let clientId = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
           !clientId.isEmpty {
            return clientId
        }
        // Fallback to GOOGLE_CLIENT_ID
        if let clientId = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String,
           !clientId.isEmpty {
            return clientId
        }
        // Hardcoded fallback
        return "719863771026-al64a24evjcndbtcn7395eqq1to8m5n2.apps.googleusercontent.com"
    }()
    
    // MARK: - Environment Detection
    
    /// Returns true if running against local development server
    static var isLocalDevelopment: Bool {
        apiURL.contains("localhost") || apiURL.contains("192.168.") || apiURL.contains("127.0.0.1")
    }
    
    /// Returns true if running against production server
    static var isProduction: Bool {
        apiURL.contains("api.calcalcal.app")
    }
    
    /// Current environment name for logging/debugging
    static var environmentName: String {
        #if DEBUG
        return "Debug (Local)"
        #elseif STAGING
        return "Staging"
        #else
        return "Release (Production)"
        #endif
    }
}

// MARK: - Debug Helpers
#if DEBUG
extension Configuration {
    /// Print current configuration (for debugging)
    static func printConfiguration() {
        dlog("""
        🔧 Configuration:
           Environment: \(environmentName)
           API URL: \(apiURL)
           Media URL: \(mediaBaseURL)
           Local Dev: \(isLocalDevelopment)
           Production: \(isProduction)
        """)
    }
}
#endif
