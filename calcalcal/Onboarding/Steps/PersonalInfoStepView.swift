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
        VStack(spacing: DSSpacing.xl) {
            // Header
            VStack(spacing: DSSpacing.smd) {
                Text("About You")
                    .font(.dsTitle1)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("This helps us calculate your daily calorie needs accurately.")
                    .font(.dsBody)
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.top, DSSpacing.md)

            VStack(spacing: DSSpacing.lg) {
                // Age picker
                VStack(spacing: DSSpacing.sm) {
                    HStack {
                        Text("Age")
                            .font(.dsSubheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(DSColors.textSecondary)

                        if hasAgeFromHealthKit {
                            Text("(from Health)")
                                .font(.dsCaption)
                                .foregroundColor(DSColors.success)
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
                        .font(.dsTitle3)
                        .fontWeight(.bold)
                        .foregroundColor(DSColors.textPrimary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                        .fill(DSColors.surfaceSecondary)
                )

                // Gender selector
                VStack(spacing: DSSpacing.smd) {
                    HStack {
                        Text("Biological Sex")
                            .font(.dsSubheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(DSColors.textSecondary)

                        if hasGenderFromHealthKit {
                            Text("(from Health)")
                                .font(.dsCaption)
                                .foregroundColor(DSColors.success)
                        }

                        Spacer()
                    }

                    HStack(spacing: DSSpacing.smd) {
                        ForEach(Gender.allCases, id: \.self) { gender in
                            genderButton(gender)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                        .fill(DSColors.surfaceSecondary)
                )
            }
            .padding(.horizontal, DSSpacing.lg)

            Spacer()

            // Navigation
            VStack(spacing: DSSpacing.smd) {
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
                        .font(.dsHeadline)
                        .foregroundColor(DSColors.textInverted)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedGender != nil ? DSColors.primary : DSColors.disabled)
                        .cornerRadius(DSCornerRadius.md)
                }
                .disabled(selectedGender == nil)

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
            VStack(spacing: DSSpacing.sm) {
                Image(systemName: genderIcon(gender))
                    .font(Font.dsCustom(weight: .regular, size: 24))
                    .foregroundColor(isSelected ? DSColors.textInverted : DSColors.textPrimary)

                Text(gender.displayName)
                    .font(.dsSubheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? DSColors.textInverted : DSColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.md)
                    .fill(isSelected ? DSColors.primary : DSColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSCornerRadius.md)
                    .stroke(isSelected ? DSColors.primary : DSColors.disabled, lineWidth: 1)
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
