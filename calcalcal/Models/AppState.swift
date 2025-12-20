import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var authManager = AuthManager()
    
    /// Coordinator for managing onboarding flow
    /// Lazy-initialized when onboarding is needed
    @Published var onboardingCoordinator: OnboardingCoordinator?
    
    /// HealthKit manager for health data sync
    let healthKitManager = HealthKitManager.shared
    
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
        
        // Sync HealthKit data on app launch if authorized
        Task {
            await syncHealthKitDataOnLaunch()
        }
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
    
    /// Whether the current user has a temporary (non-OAuth) account
    var isTemporaryUser: Bool {
        authManager.isTemporaryUser
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
    /// Clears both backend and local onboarding completion status
    func resetOnboarding() async {
        print("[AppState] Resetting onboarding")
        
        // Clear local UserDefaults
        UserDefaults.standard.set(false, forKey: Self.onboardingCompletedKey)
        
        // Reset coordinator
        onboardingCoordinator?.reset()
        onboardingCoordinator = nil
        
        // Update backend if user is authenticated
        if authManager.isAuthenticated {
            do {
                print("[AppState] Updating backend to reset onboarding_completed")
                let updatedUser = try await authManager.updateProfile(["onboarding_completed": false])
                print("[AppState] Backend updated successfully. User onboarding_completed: \(updatedUser.onboardingCompleted ?? false)")
            } catch {
                print("[AppState] Failed to update backend: \(error.localizedDescription)")
                // Continue anyway - local reset is done
            }
        }
        
        // Notify observers
        objectWillChange.send()
    }
    
    // MARK: - HealthKit Sync
    
    /// Sync health data from HealthKit on app launch
    /// Only syncs if HealthKit is available and user has previously authorized
    func syncHealthKitDataOnLaunch() async {
        // Only sync if HealthKit is available and sync is enabled
        guard healthKitManager.isAvailable && healthKitManager.isSyncEnabled else {
            print("[AppState] HealthKit sync skipped - not available or disabled")
            return
        }
        
        // Only sync if user is authenticated
        guard authManager.isAuthenticated else {
            print("[AppState] HealthKit sync skipped - user not authenticated")
            return
        }
        
        print("[AppState] Starting HealthKit data sync on launch")
        
        do {
            // Read health data from HealthKit
            let (weight, height, gender, age) = try await healthKitManager.readAllHealthData()
            
            // Check if we have any data to update
            guard weight != nil || height != nil || gender != nil || age != nil else {
                print("[AppState] No HealthKit data available to sync")
                return
            }
            
            // Compare with current user data and update if needed
            var updates: [String: Any] = [:]
            
            if let hkWeight = weight, let currentWeight = currentUser?.weightKg {
                // Only update if significantly different (more than 0.5 kg)
                if abs(hkWeight - currentWeight) > 0.5 {
                    updates["weight_kg"] = hkWeight
                    print("[AppState] HealthKit weight differs: \(hkWeight) vs \(currentWeight)")
                }
            } else if let hkWeight = weight, currentUser?.weightKg == nil {
                updates["weight_kg"] = hkWeight
                print("[AppState] Importing HealthKit weight: \(hkWeight)")
            }
            
            if let hkHeight = height, let currentHeight = currentUser?.heightCm {
                // Only update if significantly different (more than 1 cm)
                if abs(hkHeight - currentHeight) > 1 {
                    updates["height_cm"] = hkHeight
                    print("[AppState] HealthKit height differs: \(hkHeight) vs \(currentHeight)")
                }
            } else if let hkHeight = height, currentUser?.heightCm == nil {
                updates["height_cm"] = hkHeight
                print("[AppState] Importing HealthKit height: \(hkHeight)")
            }
            
            if let hkGender = gender, currentUser?.gender == nil {
                updates["gender"] = hkGender
                print("[AppState] Importing HealthKit gender: \(hkGender)")
            }
            
            if let hkAge = age, currentUser?.age == nil {
                updates["age"] = hkAge
                print("[AppState] Importing HealthKit age: \(hkAge)")
            }
            
            // Update profile if we have changes
            if !updates.isEmpty {
                print("[AppState] Updating profile with HealthKit data: \(updates)")
                await updateUserProfileWithHealthData(updates)
            } else {
                print("[AppState] No profile updates needed from HealthKit")
            }
            
            // Mark sync complete
            healthKitManager.markSynced()
            
        } catch {
            print("[AppState] HealthKit sync error: \(error.localizedDescription)")
        }
    }
    
    /// Update user profile with health data from HealthKit
    private func updateUserProfileWithHealthData(_ updates: [String: Any]) async {
        guard authManager.isAuthenticated else {
            print("[AppState] Cannot update profile - user not authenticated")
            return
        }
        
        do {
            print("[AppState] Updating user profile with HealthKit data: \(updates)")
            let updatedUser = try await authManager.updateProfile(updates)
            print("[AppState] Profile updated successfully")
            print("[AppState] Updated user - Weight: \(updatedUser.weightKg ?? 0) kg, Height: \(updatedUser.heightCm ?? 0) cm, Age: \(updatedUser.age ?? 0)")
            
            // The backend auto-recalculates calorie goal when health fields change
            // So updating weight/height/age would trigger a new daily calorie goal
            if let newCalorieGoal = updatedUser.dailyCalorieGoal {
                print("[AppState] New calorie goal calculated: \(newCalorieGoal) kcal")
            }
            
            // Notify observers that user data has changed
            await MainActor.run {
                objectWillChange.send()
            }
        } catch {
            print("[AppState] Failed to update profile with HealthKit data: \(error.localizedDescription)")
            // Don't throw - sync can still succeed even if profile update fails
        }
    }
    
    /// Manually trigger HealthKit sync (called from Profile view)
    /// This always updates values from HealthKit, even if they're similar
    func syncHealthKitDataManually() async {
        // Only sync if HealthKit is available and sync is enabled
        guard healthKitManager.isAvailable && healthKitManager.isSyncEnabled else {
            print("[AppState] HealthKit sync skipped - not available or disabled")
            return
        }
        
        // Only sync if user is authenticated
        guard authManager.isAuthenticated else {
            print("[AppState] HealthKit sync skipped - user not authenticated")
            return
        }
        
        print("[AppState] Starting manual HealthKit data sync")
        
        do {
            // Read health data from HealthKit
            let (weight, height, gender, age) = try await healthKitManager.readAllHealthData()
            
            // Check if we have any data to update
            guard weight != nil || height != nil || gender != nil || age != nil else {
                print("[AppState] No HealthKit data available to sync")
                return
            }
            
            // Build updates - for manual sync, always update if HealthKit has data
            var updates: [String: Any] = [:]
            
            if let hkWeight = weight {
                updates["weight_kg"] = hkWeight
                print("[AppState] Importing HealthKit weight: \(hkWeight) kg")
            }
            
            if let hkHeight = height {
                updates["height_cm"] = hkHeight
                print("[AppState] Importing HealthKit height: \(hkHeight) cm")
            }
            
            if let hkGender = gender {
                updates["gender"] = hkGender
                print("[AppState] Importing HealthKit gender: \(hkGender)")
            }
            
            if let hkAge = age {
                updates["age"] = hkAge
                print("[AppState] Importing HealthKit age: \(hkAge)")
            }
            
            // Update profile if we have changes
            if !updates.isEmpty {
                print("[AppState] Updating profile with HealthKit data: \(updates)")
                await updateUserProfileWithHealthData(updates)
            } else {
                print("[AppState] No profile updates needed from HealthKit")
            }
            
            // Mark sync complete
            healthKitManager.markSynced()
            
        } catch {
            print("[AppState] HealthKit sync error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Account Management
    
    /// Delete user account and handle navigation
    func deleteAccount() async {
        do {
            try await authManager.deleteAccount()
            
            await MainActor.run {
                // Clear all state
                onboardingCoordinator = nil
                objectWillChange.send()
            }
        } catch {
            await MainActor.run {
                self.authManager.error = "Failed to delete account: \(error.localizedDescription)"
            }
        }
    }
} 