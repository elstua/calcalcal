import SwiftUI

/// Weight input screen with two wheel pickers.
/// User selects current weight and target weight in kilograms.
struct WeightStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    
    // Weight ranges (30-200 kg)
    private let weightRange = Array(30...200)
    
    @State private var currentWeight: Int = 70
    @State private var targetWeight: Int = 70
    
    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            // Header
            VStack(spacing: DSSpacing.smd) {
                Text("Your Weight")
                    .font(.dsTitle1)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Set your current and target weight to track your progress.")
                    .font(.dsBody)
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.top, DSSpacing.md)
            
            // Weight pickers side by side
            HStack(spacing: DSSpacing.xl) {
                // Current weight picker
                VStack(spacing: DSSpacing.sm) {
                    Text("Current")
                        .font(.dsSubheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(DSColors.textSecondary)
                    
                    Picker("Current Weight", selection: $currentWeight) {
                        ForEach(weightRange, id: \.self) { weight in
                            Text("\(weight) kg")
                                .tag(weight)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 120, height: 150)
                    .clipped()
                    
                    Text("\(currentWeight) kg")
                        .font(.dsTitle2)
                        .fontWeight(.bold)
                        .foregroundColor(DSColors.textPrimary)
                }
                
                // Target weight picker
                VStack(spacing: DSSpacing.sm) {
                    Text("Target")
                        .font(.dsSubheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(DSColors.textSecondary)
                    
                    Picker("Target Weight", selection: $targetWeight) {
                        ForEach(weightRange, id: \.self) { weight in
                            Text("\(weight) kg")
                                .tag(weight)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 120, height: 150)
                    .clipped()
                    
                    Text("\(targetWeight) kg")
                        .font(.dsTitle2)
                        .fontWeight(.bold)
                        .foregroundColor(DSColors.success)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.xl)
                    .fill(DSColors.surfaceSecondary)
            )
            .padding(.horizontal, DSSpacing.lg)
            
            // Weight difference indicator
            weightDifferenceView
            
            Spacer()
            
            // Navigation
            VStack(spacing: DSSpacing.smd) {
                Button(action: {
                    // Save weights
                    coordinator.updateData { data in
                        data.weightKg = Double(currentWeight)
                        data.targetWeightKg = Double(targetWeight)
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
                        .background(DSColors.primary)
                        .cornerRadius(DSCornerRadius.md)
                }
                
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
            // Pre-fill if already set
            if let existing = coordinator.collectedData.weightKg {
                currentWeight = Int(existing)
            }
            if let existing = coordinator.collectedData.targetWeightKg {
                targetWeight = Int(existing)
            }
        }
    }
    
    // MARK: - Weight Difference View
    
    private var weightDifferenceView: some View {
        let difference = targetWeight - currentWeight
        let isGain = difference > 0
        let isLoss = difference < 0
        let isMaintain = difference == 0
        
        return HStack(spacing: DSSpacing.sm) {
            Image(systemName: isMaintain ? "equal.circle.fill" : (isGain ? "arrow.up.circle.fill" : "arrow.down.circle.fill"))
                .foregroundColor(isMaintain ? DSColors.info : (isGain ? DSColors.warning : DSColors.success))
            
            if isMaintain {
                Text("Maintain current weight")
            } else {
                Text("\(isGain ? "Gain" : "Lose") \(abs(difference)) kg")
            }
        }
        .font(.dsSubheadline)
        .foregroundColor(DSColors.textSecondary)
        .padding()
        .background(DSColors.surfaceSecondary)
        .cornerRadius(DSCornerRadius.md)
    }
}

// MARK: - Preview

struct WeightStepView_Previews: PreviewProvider {
    static var previews: some View {
        WeightStepView(coordinator: OnboardingCoordinator())
    }
}






