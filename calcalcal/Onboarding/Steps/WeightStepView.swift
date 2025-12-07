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
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Text("Your Weight")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Set your current and target weight to track your progress.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            // Weight pickers side by side
            HStack(spacing: 32) {
                // Current weight picker
                VStack(spacing: 8) {
                    Text("Current")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
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
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                // Target weight picker
                VStack(spacing: 8) {
                    Text("Target")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
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
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal, 24)
            
            // Weight difference indicator
            weightDifferenceView
            
            Spacer()
            
            // Navigation
            VStack(spacing: 12) {
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
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                
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
        
        return HStack(spacing: 8) {
            Image(systemName: isMaintain ? "equal.circle.fill" : (isGain ? "arrow.up.circle.fill" : "arrow.down.circle.fill"))
                .foregroundColor(isMaintain ? .blue : (isGain ? .orange : .green))
            
            if isMaintain {
                Text("Maintain current weight")
            } else {
                Text("\(isGain ? "Gain" : "Lose") \(abs(difference)) kg")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

struct WeightStepView_Previews: PreviewProvider {
    static var previews: some View {
        WeightStepView(coordinator: OnboardingCoordinator())
    }
}


