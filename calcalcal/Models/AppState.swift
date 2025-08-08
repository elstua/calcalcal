import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var authManager = AuthManager()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Forward child object changes so views depending on computed properties update
        authManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
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