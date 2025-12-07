import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var authManager = AuthManager()
    
    /// Coordinator for managing onboarding flow
    /// Lazy-initialized when onboarding is needed
    @Published var onboardingCoordinator: OnboardingCoordinator?
    
    private var cancellables = Set<AnyCancellable>()
    
    /// UserDefaults key for local onboarding completion flag
    private static let onboardingCompletedKey = "onboarding_completed"
    
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
    
    // MARK: - Onboarding
    
    /// Whether the user has completed onboarding.
    /// Checks both backend (User.onboardingCompleted) and local UserDefaults.
    /// This allows the app to work offline and sync later.
    var hasCompletedOnboarding: Bool {
        // First check backend flag (source of truth when available)
        if let backendCompleted = currentUser?.onboardingCompleted, backendCompleted {
            return true
        }
        
        // Fall back to local UserDefaults
        return UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey)
    }
    
    /// Start the onboarding flow
    /// Creates a coordinator and pre-fills data if user is returning
    func startOnboarding() {
        print("[AppState] Starting onboarding flow")
        
        let coordinator = OnboardingCoordinator()
        
        // If user has existing health data from a previous session,
        // pre-fill the onboarding data so they see their previous choices
        if let user = currentUser, user.hasHealthData {
            let existingData = user.toOnboardingData()
            coordinator.collectedData.merge(with: existingData)
            print("[AppState] Pre-filled onboarding with existing user data")
        }
        
        coordinator.start()
        self.onboardingCoordinator = coordinator
        
        // Listen for onboarding completion
        coordinator.$isCompleted
            .filter { $0 }
            .sink { [weak self] _ in
                self?.handleOnboardingCompleted()
            }
            .store(in: &cancellables)
    }
    
    /// Handle when onboarding is completed
    private func handleOnboardingCompleted() {
        print("[AppState] Onboarding completed")
        
        // Save locally immediately
        UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
        
        // TODO: Sync collected data to backend
        // This would call the profile update API with the collected data
        
        // Notify observers
        objectWillChange.send()
    }
    
    /// Reset onboarding (for debugging/testing)
    func resetOnboarding() {
        print("[AppState] Resetting onboarding")
        UserDefaults.standard.set(false, forKey: Self.onboardingCompletedKey)
        onboardingCoordinator?.reset()
        onboardingCoordinator = nil
        objectWillChange.send()
    }
} 