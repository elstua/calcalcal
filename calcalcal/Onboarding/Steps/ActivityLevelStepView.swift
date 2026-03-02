import SwiftUI

/// Activity Level selection screen.
/// User picks from five activity levels that affect calorie calculations.
struct ActivityLevelStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var selectedLevel: ActivityLevel?

    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                Text("What's your activity level?")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("This helps us calculate your daily calorie needs.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // Activity level options (scrollable for 5 cards)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        activityCard(level)
                    }
                }
                .padding(.horizontal, 24)
            }

            // Navigation
            VStack(spacing: 12) {
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
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedLevel != nil ? Color.accentColor : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(selectedLevel == nil)

                HStack {
                    Button(action: {
                        withAnimation {
                            _ = coordinator.advance(.goBack)
                        }
                    }) {
                        Text("Back")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        withAnimation {
                            _ = coordinator.advance(.skip)
                        }
                    }) {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
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
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(activityColor(level).opacity(isSelected ? 0.2 : 0.1))
                        .frame(width: 48, height: 48)

                    Image(systemName: activityIcon(level))
                        .font(.system(size: 20))
                        .foregroundColor(activityColor(level))
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(level.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.05), radius: isSelected ? 8 : 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
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
            return .gray
        case .light:
            return .blue
        case .moderate:
            return .orange
        case .active:
            return .green
        case .veryActive:
            return .red
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
