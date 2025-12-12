import SwiftUI

/// Final screen - everything is set up and user is ready to start.
/// Shows a summary of their data and a button to enter the app.
struct ReadyStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success icon with animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 160, height: 160)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
            }
            
            // Success message
            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Your profile is ready. Start tracking your calories with natural language.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Data summary (if available)
            if hasAnyData {
                dataSummaryView
            }
            
            Spacer()
            
            // Start button
            VStack(spacing: 12) {
                Button(action: {
                    withAnimation {
                        _ = coordinator.advance(.complete)
                    }
                }) {
                    HStack {
                        Text("Start Tracking")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    withAnimation {
                        _ = coordinator.advance(.goBack)
                    }
                }) {
                    Text("Go Back")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Data Summary
    
    private var hasAnyData: Bool {
        let data = coordinator.collectedData
        return data.weightKg != nil || data.heightCm != nil || data.activityLevel != nil
    }
    
    private var dataSummaryView: some View {
        VStack(spacing: 12) {
            Text("Your Profile")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 24) {
                if let weight = coordinator.collectedData.weightKg {
                    summaryItem(icon: "scalemass", value: "\(Int(weight))", unit: "kg")
                }
                
                if let height = coordinator.collectedData.heightCm {
                    summaryItem(icon: "ruler", value: "\(Int(height))", unit: "cm")
                }
                
                if let activity = coordinator.collectedData.activityLevel,
                   let level = ActivityLevel(rawValue: activity) {
                    summaryItem(icon: activityIcon(level), value: level.displayName, unit: "")
                }
            }
            
            // Show calculated calorie goal if available
            if let goal = coordinator.collectedData.calculateCalorieGoal() {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("Estimated daily goal:")
                    Text("\(goal) kcal")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 24)
    }
    
    private func summaryItem(icon: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
            
            HStack(spacing: 2) {
                Text(value)
                    .font(.headline)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func activityIcon(_ level: ActivityLevel) -> String {
        switch level {
        case .small:
            return "figure.stand"
        case .moderate:
            return "figure.walk"
        case .active:
            return "figure.run"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ReadyStepView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ReadyStepView(coordinator: OnboardingCoordinator())
                .previewDisplayName("Empty Data")
            
            ReadyStepView(coordinator: OnboardingCoordinator.previewWithData)
                .previewDisplayName("With Data")
        }
    }
}
#endif


