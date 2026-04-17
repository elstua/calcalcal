import SwiftUI

/// Final screen - everything is set up and user is ready to start.
/// Shows a summary of their data and a button to enter the app.
struct ReadyStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    
    var body: some View {
        VStack(spacing: DSSpacing.xl) {
            Spacer()
            
            // Success icon with animation
            ZStack {
                Circle()
                    .fill(DSColors.success.opacity(0.15))
                    .frame(width: 160, height: 160)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(Font.dsCustom(weight: .regular, size: 80))
                    .foregroundColor(DSColors.success)
            }
            
            // Success message
            VStack(spacing: DSSpacing.md) {
                Text("You're All Set!")
                    .font(.dsDisplay)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Your profile is ready. Start tracking your calories with natural language.")
                    .font(.dsBody)
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSSpacing.xl)
            }
            
            // Data summary (if available)
            if hasAnyData {
                dataSummaryView
            }
            
            Spacer()
            
            // Start button
            VStack(spacing: DSSpacing.smd) {
                Button(action: {
                    withAnimation {
                        _ = coordinator.advance(.complete)
                    }
                }) {
                    HStack {
                        Text("Start Tracking")
                        Image(systemName: "arrow.right")
                    }
                    .font(.dsHeadline)
                    .foregroundColor(DSColors.textInverted)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DSColors.success)
                    .cornerRadius(DSCornerRadius.md)
                }
                
                Button(action: {
                    withAnimation {
                        _ = coordinator.advance(.goBack)
                    }
                }) {
                    Text("Go Back")
                        .font(.dsSubheadline)
                        .foregroundColor(DSColors.textSecondary)
                }
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.bottom, DSSpacing.xl)
        }
    }
    
    // MARK: - Data Summary
    
    private var hasAnyData: Bool {
        let data = coordinator.collectedData
        return data.weightKg != nil || data.heightCm != nil || data.activityLevel != nil
    }
    
    private var dataSummaryView: some View {
        VStack(spacing: DSSpacing.smd) {
            Text("Your Profile")
                .font(.dsSubheadline)
                .fontWeight(.semibold)
                .foregroundColor(DSColors.textSecondary)
            
            HStack(spacing: DSSpacing.lg) {
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
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(DSColors.warning)
                    Text("Estimated daily goal:")
                    Text("\(goal) kcal")
                        .fontWeight(.semibold)
                }
                .font(.dsSubheadline)
                .foregroundColor(DSColors.textSecondary)
                .padding(.top, DSSpacing.sm)
            }
        }
        .padding()
        .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                .fill(DSColors.surfaceSecondary)
        )
        .padding(.horizontal, DSSpacing.lg)
    }
    
    private func summaryItem(icon: String, value: String, unit: String) -> some View {
        VStack(spacing: DSSpacing.xs) {
            Image(systemName: icon)
                .font(.dsTitle3)
                .foregroundColor(DSColors.primary)
            
            HStack(spacing: DSSpacing.xxs) {
                Text(value)
                    .font(.dsHeadline)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.dsCaption)
                        .foregroundColor(DSColors.textSecondary)
                }
            }
        }
    }
    
    private func activityIcon(_ level: ActivityLevel) -> String {
        switch level {
        case .sedentary:
            return "figure.stand"
        case .light:
            return "figure.walk"
        case .moderate:
            return "figure.walk.motion"
        case .active:
            return "figure.run"
        case .veryActive:
            return "figure.highintensity.intervaltraining"
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





