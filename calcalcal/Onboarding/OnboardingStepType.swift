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
    case aboutApp = 0       // Carousel with 3 feature highlights
    case healthKit = 1      // HealthKit permission request (mocked for now)
    case personalInfo = 2   // Age and gender (fallback if HealthKit didn't provide them)
    case activityLevel = 3  // Activity level selection
    case weight = 4         // Current and target weight pickers
    case height = 5         // Height picker
    case createAccount = 6  // Account creation prompt (temporary users only)
    case ready = 7          // Completion screen - all set!

    var id: Int { rawValue }

    /// Human-readable title for each step (useful for debugging/analytics)
    var title: String {
        switch self {
        case .aboutApp:
            return "About App"
        case .healthKit:
            return "HealthKit"
        case .personalInfo:
            return "Personal Info"
        case .activityLevel:
            return "Activity Level"
        case .weight:
            return "Weight"
        case .height:
            return "Height"
        case .createAccount:
            return "Create Account"
        case .ready:
            return "Ready"
        }
    }

    /// Whether this step can be skipped by the user
    var canSkip: Bool {
        switch self {
        case .aboutApp, .ready:
            // Informational screens - no skip button needed (just continue)
            return false
        case .healthKit:
            // User can skip HealthKit permission
            return true
        case .personalInfo:
            // User can skip age/gender input (will use defaults)
            return true
        case .activityLevel, .weight, .height:
            // Data collection screens - user can skip but we encourage completion
            return true
        case .createAccount:
            // User can skip account creation (handled in step view with "Skip for now")
            return false
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
