import Foundation

/// Protocol that all onboarding step views should conform to.
/// This allows the coordinator to manage flow without knowing specific screen details.
///
/// Each step view will call `onAdvance(action)` when the user interacts,
/// and the coordinator handles what happens next.
protocol OnboardingStep {
    /// The type of this step (used for identification and ordering)
    var stepType: OnboardingStepType { get }
    
    /// Whether this step can be skipped
    var canSkip: Bool { get }
}

/// Actions that a step view can trigger to advance through onboarding.
/// The coordinator interprets these and updates state accordingly.
enum OnboardingAdvancement {
    /// Move to the next step in sequence
    case next
    
    /// Skip the current step (move to next without saving data)
    case skip
    
    /// Complete onboarding entirely (typically from the last step)
    case complete
    
    /// Go back to the previous step
    case goBack
}

/// Result of an advancement attempt, used for error handling
enum OnboardingAdvancementResult {
    case success
    case alreadyCompleted
    case invalidStep
    case error(String)
}

