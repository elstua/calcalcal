import Foundation

/// Tracks analytics for the onboarding flow.
/// Records which screens users have viewed/completed for product insights.
///
/// This data helps understand:
/// - Where users drop off in onboarding
/// - Which steps take longest
/// - Overall completion rates
struct OnboardingAnalytics: Codable, Equatable {
    /// Timestamp when onboarding was started
    var startedAt: Date?
    
    /// Timestamp when onboarding was completed (nil if not yet completed)
    var completedAt: Date?
    
    /// Record of each step's analytics
    var stepRecords: [StepRecord]
    
    /// The user ID associated with this analytics session
    var userId: String?
    
    // MARK: - Initialization
    
    init() {
        self.stepRecords = []
    }
    
    init(userId: String?) {
        self.userId = userId
        self.stepRecords = []
    }
    
    // MARK: - Step Record
    
    /// Analytics record for a single onboarding step
    struct StepRecord: Codable, Equatable, Identifiable {
        var id: Int { stepType.rawValue }
        
        /// Which step this record is for
        let stepType: OnboardingStepType
        
        /// When the user first viewed this step
        var viewedAt: Date?
        
        /// When the user completed/advanced past this step
        var completedAt: Date?
        
        /// Whether the step was skipped
        var wasSkipped: Bool
        
        /// Time spent on this step (in seconds)
        var timeSpentSeconds: TimeInterval? {
            guard let viewed = viewedAt, let completed = completedAt else {
                return nil
            }
            return completed.timeIntervalSince(viewed)
        }
        
        init(stepType: OnboardingStepType) {
            self.stepType = stepType
            self.wasSkipped = false
        }
    }
    
    // MARK: - Recording Methods
    
    /// Mark onboarding as started
    mutating func markStarted() {
        if startedAt == nil {
            startedAt = Date()
            print("[Onboarding Analytics] Started onboarding at \(startedAt!)")
        }
    }
    
    /// Record that a step was viewed
    mutating func recordStepViewed(_ stepType: OnboardingStepType) {
        if let index = stepRecords.firstIndex(where: { $0.stepType == stepType }) {
            // Already have a record, only update if not previously viewed
            if stepRecords[index].viewedAt == nil {
                stepRecords[index].viewedAt = Date()
            }
        } else {
            // Create new record
            var record = StepRecord(stepType: stepType)
            record.viewedAt = Date()
            stepRecords.append(record)
        }
        print("[Onboarding Analytics] Step viewed: \(stepType.title)")
    }
    
    /// Record that a step was completed
    mutating func recordStepCompleted(_ stepType: OnboardingStepType, wasSkipped: Bool = false) {
        if let index = stepRecords.firstIndex(where: { $0.stepType == stepType }) {
            stepRecords[index].completedAt = Date()
            stepRecords[index].wasSkipped = wasSkipped
        } else {
            // Create new record if somehow we don't have one
            var record = StepRecord(stepType: stepType)
            record.viewedAt = Date()
            record.completedAt = Date()
            record.wasSkipped = wasSkipped
            stepRecords.append(record)
        }
        
        let action = wasSkipped ? "skipped" : "completed"
        if let record = stepRecords.first(where: { $0.stepType == stepType }),
           let timeSpent = record.timeSpentSeconds {
            print("[Onboarding Analytics] Step \(action): \(stepType.title) (time: \(String(format: "%.1f", timeSpent))s)")
        } else {
            print("[Onboarding Analytics] Step \(action): \(stepType.title)")
        }
    }
    
    /// Mark onboarding as fully completed
    mutating func markCompleted() {
        completedAt = Date()
        if let started = startedAt {
            let totalTime = completedAt!.timeIntervalSince(started)
            print("[Onboarding Analytics] Completed onboarding in \(String(format: "%.1f", totalTime))s")
        } else {
            print("[Onboarding Analytics] Completed onboarding")
        }
    }
    
    // MARK: - Query Methods
    
    /// Check if a specific step has been viewed
    func hasViewed(_ stepType: OnboardingStepType) -> Bool {
        stepRecords.first(where: { $0.stepType == stepType })?.viewedAt != nil
    }
    
    /// Check if a specific step has been completed
    func hasCompleted(_ stepType: OnboardingStepType) -> Bool {
        stepRecords.first(where: { $0.stepType == stepType })?.completedAt != nil
    }
    
    /// Get the last completed step
    var lastCompletedStep: OnboardingStepType? {
        stepRecords
            .filter { $0.completedAt != nil }
            .sorted { $0.stepType.rawValue > $1.stepType.rawValue }
            .first?.stepType
    }
    
    /// Calculate total time spent in onboarding
    var totalTimeSpent: TimeInterval? {
        guard let started = startedAt else { return nil }
        let endTime = completedAt ?? Date()
        return endTime.timeIntervalSince(started)
    }
    
    /// Count of steps that were skipped
    var skippedStepsCount: Int {
        stepRecords.filter { $0.wasSkipped }.count
    }
    
    /// Count of steps that were completed (not skipped)
    var completedStepsCount: Int {
        stepRecords.filter { $0.completedAt != nil && !$0.wasSkipped }.count
    }
    
    // MARK: - Debug Summary
    
    /// Print a summary of analytics (useful for debugging)
    func printSummary() {
        print("[Onboarding Analytics] ===== Summary =====")
        print("  Started: \(startedAt?.description ?? "not started")")
        print("  Completed: \(completedAt?.description ?? "not completed")")
        if let total = totalTimeSpent {
            print("  Total time: \(String(format: "%.1f", total))s")
        }
        print("  Steps completed: \(completedStepsCount)/\(OnboardingStepType.totalSteps)")
        print("  Steps skipped: \(skippedStepsCount)")
        
        print("  Step breakdown:")
        for step in OnboardingStepType.allCases {
            if let record = stepRecords.first(where: { $0.stepType == step }) {
                let status: String
                if record.completedAt != nil {
                    status = record.wasSkipped ? "skipped" : "completed"
                } else if record.viewedAt != nil {
                    status = "viewed"
                } else {
                    status = "not started"
                }
                let time = record.timeSpentSeconds.map { String(format: "%.1fs", $0) } ?? "-"
                print("    - \(step.title): \(status) (\(time))")
            } else {
                print("    - \(step.title): not started")
            }
        }
        print("[Onboarding Analytics] ===================")
    }
}

