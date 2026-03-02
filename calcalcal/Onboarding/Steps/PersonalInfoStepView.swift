import SwiftUI

/// Personal Info step for collecting age and gender.
/// Shows only when HealthKit didn't provide these values.
/// Pre-fills from HealthKit data if available.
struct PersonalInfoStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator

    private let ageRange = Array(13...99)

    @State private var selectedAge: Int = 25
    @State private var selectedGender: Gender?

    private var hasAgeFromHealthKit: Bool {
        coordinator.collectedData.age != nil
    }

    private var hasGenderFromHealthKit: Bool {
        coordinator.collectedData.gender != nil
    }

    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                Text("About You")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("This helps us calculate your daily calorie needs accurately.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            VStack(spacing: 24) {
                // Age picker
                VStack(spacing: 8) {
                    HStack {
                        Text("Age")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        if hasAgeFromHealthKit {
                            Text("(from Health)")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }

                        Spacer()
                    }

                    Picker("Age", selection: $selectedAge) {
                        ForEach(ageRange, id: \.self) { age in
                            Text("\(age) years").tag(age)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 120)
                    .clipped()

                    Text("\(selectedAge) years old")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                )

                // Gender selector
                VStack(spacing: 12) {
                    HStack {
                        Text("Biological Sex")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        if hasGenderFromHealthKit {
                            Text("(from Health)")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }

                        Spacer()
                    }

                    HStack(spacing: 12) {
                        ForEach(Gender.allCases, id: \.self) { gender in
                            genderButton(gender)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Navigation
            VStack(spacing: 12) {
                Button(action: {
                    coordinator.updateData { data in
                        data.age = selectedAge
                        data.gender = selectedGender?.rawValue
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
                        .background(selectedGender != nil ? Color.accentColor : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(selectedGender == nil)

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
            // Pre-fill from HealthKit data if available
            if let existingAge = coordinator.collectedData.age {
                selectedAge = existingAge
            }
            if let existingGender = coordinator.collectedData.gender,
               let gender = Gender(rawValue: existingGender) {
                selectedGender = gender
            }
        }
    }

    // MARK: - Gender Button

    private func genderButton(_ gender: Gender) -> some View {
        let isSelected = selectedGender == gender

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedGender = gender
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: genderIcon(gender))
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .primary)

                Text(gender.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func genderIcon(_ gender: Gender) -> String {
        switch gender {
        case .male:
            return "figure.stand"
        case .female:
            return "figure.stand.dress"
        case .other:
            return "person.fill"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PersonalInfoStepView_Previews: PreviewProvider {
    static var previews: some View {
        PersonalInfoStepView(coordinator: OnboardingCoordinator())
    }
}
#endif
