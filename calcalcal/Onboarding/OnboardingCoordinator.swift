import Foundation
import Combine

/// Manages the state and flow of the onboarding process.
///
/// Responsibilities:
/// - Track current step in onboarding flow
/// - Store and persist collected data (UserDefaults)
/// - Handle advancement actions from step views
/// - Sync with backend when onboarding completes
/// - Support returning users (pre-fill data from previous sessions)
///
/// Usage:
/// ```swift
/// @StateObject var coordinator = OnboardingCoordinator()
///
/// // In step views:
/// coordinator.advance(.next)
/// coordinator.updateData { $0.weightKg = 75.0 }
/// ```
class OnboardingCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current step being displayed
    @Published private(set) var currentStep: OnboardingStepType = .welcome
    
    /// All data collected during onboarding
    @Published var collectedData: OnboardingData = OnboardingData()
    
    /// Analytics for tracking user progress
    @Published private(set) var analytics: OnboardingAnalytics = OnboardingAnalytics()
    
    /// Whether onboarding has been completed
    @Published private(set) var isCompleted: Bool = false
    
    /// Whether we're currently saving/syncing data
    @Published private(set) var isSaving: Bool = false
    
    /// Error message if something goes wrong
    @Published var error: String?
    
    // MARK: - UserDefaults Keys
    
    private enum StorageKeys {
        static let onboardingData = "onboarding_collected_data"
        static let onboardingAnalytics = "onboarding_analytics"
        static let onboardingCompleted = "onboarding_completed"
        static let currentStepIndex = "onboarding_current_step"
    }
    
    // MARK: - Private Properties
    
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize with optional custom UserDefaults (useful for testing)
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Load persisted state
        loadPersistedState()
        
        // Set up auto-save when data changes
        setupAutoSave()
        
        print("[OnboardingCoordinator] Initialized at step: \(currentStep.title)")
    }
    
    // MARK: - Public Methods
    
    /// Start onboarding (call when onboarding view appears)
    func start() {
        analytics.markStarted()
        analytics.recordStepViewed(currentStep)
        persistState()
        print("[OnboardingCoordinator] Onboarding started")
    }
    
    /// Handle advancement action from a step view
    /// - Parameter action: The advancement action to perform
    /// - Returns: Result indicating success or failure
    @discardableResult
    func advance(_ action: OnboardingAdvancement) -> OnboardingAdvancementResult {
        print("[OnboardingCoordinator] Advance action: \(action) from step: \(currentStep.title)")
        
        guard !isCompleted else {
            print("[OnboardingCoordinator] Warning: Trying to advance but onboarding already completed")
            return .alreadyCompleted
        }
        
        switch action {
        case .next:
            return moveToNextStep(wasSkipped: false)
            
        case .skip:
            return moveToNextStep(wasSkipped: true)
            
        case .complete:
            return completeOnboarding()
            
        case .goBack:
            return moveToPreviousStep()
        }
    }
    
    /// Update collected data using a closure
    /// This is the preferred way to update data as it ensures persistence
    func updateData(_ update: (inout OnboardingData) -> Void) {
        update(&collectedData)
        print("[OnboardingCoordinator] Data updated")
        // Auto-save will handle persistence
    }
    
    /// Pre-fill data from backend user profile (for returning users)
    func prefillFromUser(_ user: User) {
        print("[OnboardingCoordinator] Pre-filling data from user profile")
        
        // Map user fields to onboarding data
        // Note: This requires User model to have these fields
        // For now, we'll leave this as a placeholder
        // TODO: Update when User model is extended with health fields
        
        // Example of how it would work:
        // collectedData.weightKg = user.weightKg
        // collectedData.heightCm = user.heightCm
        // etc.
        
        persistState()
    }
    
    /// Pre-fill data from a dictionary (useful for backend sync)
    func prefillFromDictionary(_ dict: [String: Any]) {
        print("[OnboardingCoordinator] Pre-filling data from dictionary")
        
        if let weight = dict["weight_kg"] as? Double {
            collectedData.weightKg = weight
        }
        if let height = dict["height_cm"] as? Double {
            collectedData.heightCm = height
        }
        if let age = dict["age"] as? Int {
            collectedData.age = age
        }
        if let gender = dict["gender"] as? String {
            collectedData.gender = gender
        }
        if let activity = dict["activity_level"] as? String {
            collectedData.activityLevel = activity
        }
        if let targetWeight = dict["target_weight_kg"] as? Double {
            collectedData.targetWeightKg = targetWeight
        }
        if let calorieGoal = dict["daily_calorie_goal"] as? Int {
            collectedData.calorieGoal = calorieGoal
        }
        
        persistState()
    }
    
    /// Reset onboarding to initial state (useful for debugging/testing)
    func reset() {
        print("[OnboardingCoordinator] Resetting onboarding")
        
        currentStep = .welcome
        collectedData = OnboardingData()
        analytics = OnboardingAnalytics()
        isCompleted = false
        error = nil
        
        // Clear persisted state
        userDefaults.removeObject(forKey: StorageKeys.onboardingData)
        userDefaults.removeObject(forKey: StorageKeys.onboardingAnalytics)
        userDefaults.removeObject(forKey: StorageKeys.onboardingCompleted)
        userDefaults.removeObject(forKey: StorageKeys.currentStepIndex)
        
        print("[OnboardingCoordinator] Reset complete")
    }
    
    /// Go to a specific step (useful for debugging)
    func goToStep(_ step: OnboardingStepType) {
        print("[OnboardingCoordinator] Debug: jumping to step \(step.title)")
        currentStep = step
        analytics.recordStepViewed(step)
        persistState()
    }
    
    // MARK: - Computed Properties
    
    /// Progress through onboarding (0.0 to 1.0)
    var progress: Double {
        Double(currentStep.rawValue) / Double(OnboardingStepType.totalSteps - 1)
    }
    
    /// Current step number (1-indexed for display)
    var currentStepNumber: Int {
        currentStep.rawValue + 1
    }
    
    /// Total number of steps
    var totalSteps: Int {
        OnboardingStepType.totalSteps
    }
    
    /// Whether we can go back from current step
    var canGoBack: Bool {
        !currentStep.isFirst
    }
    
    /// Whether current step can be skipped
    var canSkip: Bool {
        currentStep.canSkip
    }
    
    // MARK: - Private Methods
    
    private func moveToNextStep(wasSkipped: Bool) -> OnboardingAdvancementResult {
        // Record completion of current step
        analytics.recordStepCompleted(currentStep, wasSkipped: wasSkipped)
        
        // Check if this was the last step
        if currentStep.isLast {
            return completeOnboarding()
        }
        
        // Move to next step
        guard let nextStep = currentStep.next else {
            print("[OnboardingCoordinator] Error: No next step available")
            return .invalidStep
        }
        
        currentStep = nextStep
        analytics.recordStepViewed(nextStep)
        persistState()
        
        print("[OnboardingCoordinator] Moved to step: \(nextStep.title)")
        return .success
    }
    
    private func moveToPreviousStep() -> OnboardingAdvancementResult {
        guard let previousStep = currentStep.previous else {
            print("[OnboardingCoordinator] Warning: No previous step available")
            return .invalidStep
        }
        
        currentStep = previousStep
        persistState()
        
        print("[OnboardingCoordinator] Moved back to step: \(previousStep.title)")
        return .success
    }
    
    private func completeOnboarding() -> OnboardingAdvancementResult {
        print("[OnboardingCoordinator] Completing onboarding...")
        
        // Mark final step as completed
        analytics.recordStepCompleted(currentStep, wasSkipped: false)
        analytics.markCompleted()
        
        // Auto-calculate calorie goal if not set
        if collectedData.calorieGoal == nil {
            collectedData.calorieGoal = collectedData.calculateCalorieGoal()
            print("[OnboardingCoordinator] Auto-calculated calorie goal: \(collectedData.calorieGoal ?? 0)")
        }
        
        isCompleted = true
        persistState()
        
        // Print analytics summary
        analytics.printSummary()
        
        print("[OnboardingCoordinator] Onboarding completed!")
        return .success
    }
    
    // MARK: - Persistence
    
    private func loadPersistedState() {
        print("[OnboardingCoordinator] Loading persisted state...")
        
        // Load completion status
        isCompleted = userDefaults.bool(forKey: StorageKeys.onboardingCompleted)
        
        // Load current step
        let stepIndex = userDefaults.integer(forKey: StorageKeys.currentStepIndex)
        if let step = OnboardingStepType(rawValue: stepIndex) {
            currentStep = step
        }
        
        // Load collected data
        if let data = userDefaults.data(forKey: StorageKeys.onboardingData) {
            do {
                collectedData = try JSONDecoder().decode(OnboardingData.self, from: data)
                print("[OnboardingCoordinator] Loaded persisted data: weight=\(collectedData.weightKg ?? 0), height=\(collectedData.heightCm ?? 0)")
            } catch {
                print("[OnboardingCoordinator] Failed to decode persisted data: \(error)")
            }
        }
        
        // Load analytics
        if let data = userDefaults.data(forKey: StorageKeys.onboardingAnalytics) {
            do {
                analytics = try JSONDecoder().decode(OnboardingAnalytics.self, from: data)
            } catch {
                print("[OnboardingCoordinator] Failed to decode persisted analytics: \(error)")
            }
        }
        
        print("[OnboardingCoordinator] Loaded state - step: \(currentStep.title), completed: \(isCompleted)")
    }
    
    private func persistState() {
        print("[OnboardingCoordinator] Persisting state...")
        
        // Save completion status
        userDefaults.set(isCompleted, forKey: StorageKeys.onboardingCompleted)
        
        // Save current step
        userDefaults.set(currentStep.rawValue, forKey: StorageKeys.currentStepIndex)
        
        // Save collected data
        do {
            let data = try JSONEncoder().encode(collectedData)
            userDefaults.set(data, forKey: StorageKeys.onboardingData)
        } catch {
            print("[OnboardingCoordinator] Failed to encode data: \(error)")
        }
        
        // Save analytics
        do {
            let data = try JSONEncoder().encode(analytics)
            userDefaults.set(data, forKey: StorageKeys.onboardingAnalytics)
        } catch {
            print("[OnboardingCoordinator] Failed to encode analytics: \(error)")
        }
    }
    
    private func setupAutoSave() {
        // Auto-save when collectedData changes
        $collectedData
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.persistState()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension OnboardingCoordinator {
    /// Create a coordinator pre-filled with test data
    static var previewWithData: OnboardingCoordinator {
        let coordinator = OnboardingCoordinator()
        coordinator.collectedData = OnboardingData(
            weightKg: 75.0,
            heightCm: 180.0,
            age: 30,
            gender: "male",
            activityLevel: "moderate",
            targetWeightKg: 70.0,
            calorieGoal: 2200,
            weightUnit: "kg",
            heightUnit: "cm"
        )
        return coordinator
    }
    
    /// Create a coordinator at a specific step
    static func previewAtStep(_ step: OnboardingStepType) -> OnboardingCoordinator {
        let coordinator = OnboardingCoordinator()
        coordinator.currentStep = step
        return coordinator
    }
    
    /// Create a coordinator that's almost complete (for testing ready screen)
    static var previewAlmostComplete: OnboardingCoordinator {
        let coordinator = OnboardingCoordinator()
        coordinator.currentStep = .ready
        coordinator.collectedData = OnboardingData(
            weightKg: 75.0,
            heightCm: 180.0,
            age: 30,
            gender: "male",
            activityLevel: "moderate",
            targetWeightKg: 70.0
        )
        return coordinator
    }
    
    /// Print current state for debugging
    func debugPrint() {
        print("=== OnboardingCoordinator Debug ===")
        print("Current step: \(currentStep.title) (\(currentStepNumber)/\(totalSteps))")
        print("Progress: \(Int(progress * 100))%")
        print("Is completed: \(isCompleted)")
        print("Data:")
        print("  - Weight: \(collectedData.weightKg ?? 0) kg")
        print("  - Height: \(collectedData.heightCm ?? 0) cm")
        print("  - Age: \(collectedData.age ?? 0)")
        print("  - Gender: \(collectedData.gender ?? "not set")")
        print("  - Activity: \(collectedData.activityLevel ?? "not set")")
        print("  - Target weight: \(collectedData.targetWeightKg ?? 0) kg")
        print("  - Calorie goal: \(collectedData.calorieGoal ?? 0)")
        print("===================================")
    }
}
#endif

