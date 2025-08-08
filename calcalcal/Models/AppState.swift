import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var authManager = AuthManager()
    
    var isAuthenticated: Bool {
        authManager.isAuthenticated
    }
    
    var currentUser: User? {
        authManager.currentUser
    }
    
    var isLoading: Bool {
        authManager.isLoading
    }
    
    var error: String? {
        authManager.error
    }
} 