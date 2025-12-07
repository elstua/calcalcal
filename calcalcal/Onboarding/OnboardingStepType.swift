import Foundation

/// Defines all possible onboarding steps in order.
/// The raw Int value determines the display order.
/// 
/// To add a new step:
/// 1. Add a new case with the next Int value
/// 2. Add corresponding fields to OnboardingData if needed
/// 3. Create the step view
/// 4. Add case to OnboardingContainerView factory switch
enum OnboardingStepType: Int, CaseIterable, Codable, Identifiable {
    case welcome = 0
    case features = 1
    case healthData = 2
    case activityLevel = 3
    case goals = 4
    
    var id: Int { rawValue }
    
    /// Human-readable title for each step (useful for debugging/analytics)
    var title: String {
        switch self {
        case .welcome:
            return "Welcome"
        case .features:
            return "Features"
        case .healthData:
            return "Health Data"
        case .activityLevel:
            return "Activity Level"
        case .goals:
            return "Goals"
        }
    }
    
    /// Whether this step can be skipped by the user
    var canSkip: Bool {
        switch self {
        case .welcome, .features:
            // Informational screens can always be skipped
            return true
        case .healthData, .activityLevel, .goals:
            // Data collection screens - user can skip but we want to encourage completion
            return true
        }
    }
    
    /// Returns the next step, or nil if this is the last step
    var next: OnboardingStepType? {
        OnboardingStepType(rawValue: rawValue + 1)
    }
    
    /// Returns the previous step, or nil if this is the first step
    var previous: OnboardingStepType? {
        guard rawValue > 0 else { return nil }
        return OnboardingStepType(rawValue: rawValue - 1)
    }
    
    /// Check if this is the last step
    var isLast: Bool {
        self == OnboardingStepType.allCases.last
    }
    
    /// Check if this is the first step
    var isFirst: Bool {
        self == OnboardingStepType.allCases.first
    }
    
    /// Total number of steps
    static var totalSteps: Int {
        allCases.count
    }
}

