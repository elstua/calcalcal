import SwiftUI

/// Activity Level selection screen.
/// User picks from five activity levels that affect calorie calculations.
struct ActivityLevelStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var selectedLevel: ActivityLevel?

    var body: some View {
        VStack(spacing: DSSpacing.xl) {
            // Header
            VStack(spacing: DSSpacing.smd) {
                Text("What's your activity level?")
                    .font(.dsTitle1)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("This helps us calculate your daily calorie needs.")
                    .font(.dsBody)
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.top, DSSpacing.md)

            // Activity level options (scrollable for 5 cards)
            ScrollView {
                VStack(spacing: DSSpacing.smd) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        activityCard(level)
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
            }

            // Navigation
            VStack(spacing: DSSpacing.smd) {
                Button(action: {
                    // Save selection
                    if let level = selectedLevel {
                        coordinator.updateData { data in
                            data.activityLevel = level.rawValue
                        }
                    }
                    withAnimation {
                        _ = coordinator.advance(.next)
                    }
                }) {
                    Text("Continue")
                        .font(.dsHeadline)
                        .foregroundColor(DSColors.textInverted)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedLevel != nil ? DSColors.primary : DSColors.disabled)
                        .cornerRadius(DSCornerRadius.md)
                }
                .disabled(selectedLevel == nil)

                HStack {
                    Button(action: {
                        withAnimation {
                            _ = coordinator.advance(.goBack)
                        }
                    }) {
                        Text("Back")
                            .font(.dsSubheadline)
                            .foregroundColor(DSColors.textSecondary)
                    }

                    Spacer()

                    Button(action: {
                        withAnimation {
                            _ = coordinator.advance(.skip)
                        }
                    }) {
                        Text("Skip")
                            .font(.dsSubheadline)
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.bottom, DSSpacing.xl)
        }
        .onAppear {
            // Pre-fill if already selected
            if let existing = coordinator.collectedData.activityLevel {
                selectedLevel = ActivityLevel(rawValue: existing)
            }
        }
    }

    // MARK: - Activity Card

    private func activityCard(_ level: ActivityLevel) -> some View {
        let isSelected = selectedLevel == level

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedLevel = level
            }
        }) {
            HStack(spacing: DSSpacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(activityColor(level).opacity(isSelected ? 0.2 : 0.1))
                        .frame(width: 48, height: 48)

                    Image(systemName: activityIcon(level))
                        .font(.dsTitle3)
                        .foregroundColor(activityColor(level))
                }

                // Text
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    Text(level.displayName)
                        .font(.dsHeadline)
                        .foregroundColor(DSColors.textPrimary)

                    Text(level.description)
                        .font(.dsCaption)
                        .foregroundColor(DSColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.dsTitle2)
                        .foregroundColor(DSColors.primary)
                }
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.smd)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.md)
                    .fill(DSColors.surface)
                    .shadow(color: isSelected ? DSColors.primary.opacity(0.3) : DSColors.shadowLight, radius: isSelected ? 8 : 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSCornerRadius.md)
                    .stroke(isSelected ? DSColors.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helpers

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

    private func activityColor(_ level: ActivityLevel) -> Color {
        switch level {
        case .sedentary:
            return DSColors.disabled
        case .light:
            return DSColors.info
        case .moderate:
            return DSColors.warning
        case .active:
            return DSColors.success
        case .veryActive:
            return DSColors.error
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ActivityLevelStepView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityLevelStepView(coordinator: OnboardingCoordinator())
    }
}
#endif
