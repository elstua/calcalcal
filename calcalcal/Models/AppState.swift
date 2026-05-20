import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var authManager = AuthManager()
    
    /// Coordinator for managing onboarding flow
    /// Lazy-initialized when onboarding is needed
    @Published var onboardingCoordinator: OnboardingCoordinator?

    /// Current streak data
    @Published var streaksData: StreaksData?
    
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
        
        // ✅ FIX: Observe authentication state and refresh streaks when auth completes
        // This ensures streaks load correctly even if authentication finishes after init
        authManager.$isAuthenticated
            .removeDuplicates()
            .filter { $0 == true } // Only when authenticated becomes true
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    dlog("🔐 [Streaks] Authentication completed, refreshing streaks...")
                    await self?.refreshStreaks()
                }
            }
            .store(in: &cancellables)
        
        // Sync HealthKit data on app launch if authorized
        Task {
            await syncHealthKitDataOnLaunch()
            // Note: Streaks will be refreshed by the authentication observer above
            // but we still try here in case auth is already complete
            await refreshStreaks()
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
        if let backendCompleted = currentUser?.onboardingCompleted {
            return backendCompleted
        }
        
        // Fall back to local UserDefaults
        return UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey)
    }
    
    /// Start the onboarding flow
    /// Creates a coordinator and pre-fills data if user is returning
    func startOnboarding() {
        dlog("[AppState] Starting onboarding flow")
        
        let coordinator = OnboardingCoordinator()
        
        // If user has existing health data from a previous session,
        // pre-fill the onboarding data so they see their previous choices
        if let user = currentUser, user.hasHealthData {
            let existingData = user.toOnboardingData()
            coordinator.collectedData.merge(with: existingData)
            dlog("[AppState] Pre-filled onboarding with existing user data")
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
        dlog("[AppState] Onboarding completed")
        
        // Save locally immediately
        UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
        
        // TODO: Sync collected data to backend
        // This would call the profile update API with the collected data
        
        // Notify observers
        objectWillChange.send()
    }
    
    /// Reset onboarding (for debugging/testing)
    /// Clears both backend and local onboarding completion status
    @MainActor
    func resetOnboarding() async {
        dlog("[AppState] Resetting onboarding")
        
        // Clear local UserDefaults
        UserDefaults.standard.set(false, forKey: Self.onboardingCompletedKey)
        
        // Reset coordinator
        onboardingCoordinator?.reset()
        onboardingCoordinator = nil
        
        // Update backend if user is authenticated
        if authManager.isAuthenticated {
            do {
                dlog("[AppState] Updating backend to reset onboarding_completed")
                let updatedUser = try await authManager.updateProfile(["onboarding_completed": false])
                dlog("[AppState] Backend updated successfully. User onboarding_completed: \(updatedUser.onboardingCompleted ?? false)")
            } catch {
                dlog("[AppState] Failed to update backend: \(error.localizedDescription)")
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
            dlog("[AppState] HealthKit sync skipped - not available or disabled")
            return
        }
        
        // Only sync if user is authenticated
        guard authManager.isAuthenticated else {
            dlog("[AppState] HealthKit sync skipped - user not authenticated")
            return
        }
        
        dlog("[AppState] Starting HealthKit data sync on launch")
        
        do {
            // Read health data from HealthKit
            let (weight, height, gender, age) = try await healthKitManager.readAllHealthData()
            
            // Check if we have any data to update
            guard weight != nil || height != nil || gender != nil || age != nil else {
                dlog("[AppState] No HealthKit data available to sync")
                return
            }
            
            // Compare with current user data and update if needed
            var updates: [String: Any] = [:]
            
            if let hkWeight = weight, let currentWeight = currentUser?.weightKg {
                // Only update if significantly different (more than 0.5 kg)
                if abs(hkWeight - currentWeight) > 0.5 {
                    updates["weight_kg"] = hkWeight
                    dlog("[AppState] HealthKit weight differs: \(hkWeight) vs \(currentWeight)")
                }
            } else if let hkWeight = weight, currentUser?.weightKg == nil {
                updates["weight_kg"] = hkWeight
                dlog("[AppState] Importing HealthKit weight: \(hkWeight)")
            }
            
            if let hkHeight = height, let currentHeight = currentUser?.heightCm {
                // Only update if significantly different (more than 1 cm)
                if abs(hkHeight - currentHeight) > 1 {
                    updates["height_cm"] = hkHeight
                    dlog("[AppState] HealthKit height differs: \(hkHeight) vs \(currentHeight)")
                }
            } else if let hkHeight = height, currentUser?.heightCm == nil {
                updates["height_cm"] = hkHeight
                dlog("[AppState] Importing HealthKit height: \(hkHeight)")
            }
            
            if let hkGender = gender, currentUser?.gender == nil {
                updates["gender"] = hkGender
                dlog("[AppState] Importing HealthKit gender: \(hkGender)")
            }
            
            if let hkAge = age, currentUser?.age == nil {
                updates["age"] = hkAge
                dlog("[AppState] Importing HealthKit age: \(hkAge)")
            }
            
            // Update profile if we have changes
            if !updates.isEmpty {
                dlog("[AppState] Updating profile with HealthKit data: \(updates)")
                await updateUserProfileWithHealthData(updates)
            } else {
                dlog("[AppState] No profile updates needed from HealthKit")
            }
            
            // Mark sync complete
            healthKitManager.markSynced()
            
        } catch {
            dlog("[AppState] HealthKit sync error: \(error.localizedDescription)")
        }
    }
    
    /// Update user profile with health data from HealthKit
    private func updateUserProfileWithHealthData(_ updates: [String: Any]) async {
        guard authManager.isAuthenticated else {
            dlog("[AppState] Cannot update profile - user not authenticated")
            return
        }
        
        do {
            dlog("[AppState] Updating user profile with HealthKit data: \(updates)")
            let updatedUser = try await authManager.updateProfile(updates)
            dlog("[AppState] Profile updated successfully")
            dlog("[AppState] Updated user - Weight: \(updatedUser.weightKg ?? 0) kg, Height: \(updatedUser.heightCm ?? 0) cm, Age: \(updatedUser.age ?? 0)")
            
            // The backend auto-recalculates calorie goal when health fields change
            // So updating weight/height/age would trigger a new daily calorie goal
            if let newCalorieGoal = updatedUser.dailyCalorieGoal {
                dlog("[AppState] New calorie goal calculated: \(newCalorieGoal) kcal")
            }
            
            // Notify observers that user data has changed
            await MainActor.run {
                objectWillChange.send()
            }
        } catch {
            dlog("[AppState] Failed to update profile with HealthKit data: \(error.localizedDescription)")
            // Don't throw - sync can still succeed even if profile update fails
        }
    }
    
    /// Manually trigger HealthKit sync (called from Profile view)
    /// This always updates values from HealthKit, even if they're similar
    func syncHealthKitDataManually() async {
        // Only sync if HealthKit is available and sync is enabled
        guard healthKitManager.isAvailable && healthKitManager.isSyncEnabled else {
            dlog("[AppState] HealthKit sync skipped - not available or disabled")
            return
        }
        
        // Only sync if user is authenticated
        guard authManager.isAuthenticated else {
            dlog("[AppState] HealthKit sync skipped - user not authenticated")
            return
        }
        
        dlog("[AppState] Starting manual HealthKit data sync")
        
        do {
            // Read health data from HealthKit
            let (weight, height, gender, age) = try await healthKitManager.readAllHealthData()
            
            // Check if we have any data to update
            guard weight != nil || height != nil || gender != nil || age != nil else {
                dlog("[AppState] No HealthKit data available to sync")
                return
            }
            
            // Build updates - for manual sync, always update if HealthKit has data
            var updates: [String: Any] = [:]
            
            if let hkWeight = weight {
                updates["weight_kg"] = hkWeight
                dlog("[AppState] Importing HealthKit weight: \(hkWeight) kg")
            }
            
            if let hkHeight = height {
                updates["height_cm"] = hkHeight
                dlog("[AppState] Importing HealthKit height: \(hkHeight) cm")
            }
            
            if let hkGender = gender {
                updates["gender"] = hkGender
                dlog("[AppState] Importing HealthKit gender: \(hkGender)")
            }
            
            if let hkAge = age {
                updates["age"] = hkAge
                dlog("[AppState] Importing HealthKit age: \(hkAge)")
            }
            
            // Update profile if we have changes
            if !updates.isEmpty {
                dlog("[AppState] Updating profile with HealthKit data: \(updates)")
                await updateUserProfileWithHealthData(updates)
            } else {
                dlog("[AppState] No profile updates needed from HealthKit")
            }
            
            // Mark sync complete
            healthKitManager.markSynced()
            
        } catch {
            dlog("[AppState] HealthKit sync error: \(error.localizedDescription)")
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
                streaksData = nil
                objectWillChange.send()
            }
        } catch {
            await MainActor.run {
                self.authManager.error = "Failed to delete account: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Streaks
    
    func refreshStreaks() async {
        guard authManager.isAuthenticated else {
            dlog("⚠️ [Streaks] Cannot refresh - not authenticated")
            return
        }
        
        dlog("🔄 [Streaks] Fetching from backend...")
        do {
            let data = try await DiaryAPI.getStreaks()
            await MainActor.run {
                self.streaksData = data
                dlog("✅ [Streaks] Updated: current=\(data.currentStreak), longest=\(data.longestStreak), total=\(data.totalDaysWithEntries)")
            }
        } catch {
            dlog("❌ [Streaks] Failed: \(error.localizedDescription)")
        }
    }
} 
