import UIKit
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Configure Google Sign-In
        configureGoogleSignIn()
        
        return true
    }
    
    // MARK: - Google Sign-In Configuration
    
    private func configureGoogleSignIn() {
        let clientId = Configuration.googleClientId
        guard !clientId.isEmpty else {
            dlog("⚠️ Google Sign-In: No client ID configured. Set GOOGLE_CLIENT_ID in Info.plist or Configuration.swift")
            return
        }
        
        let config = GIDConfiguration(clientID: clientId)
        GIDSignIn.sharedInstance.configuration = config
        dlog("✅ Google Sign-In configured with client ID: \(clientId.prefix(20))...")
    }
    
    // Handle URL for Google Sign-In callback
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Handle Google Sign-In redirect URL
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        
        // Handle other URL schemes if needed
        return false
    }
}


