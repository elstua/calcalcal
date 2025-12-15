import SwiftUI

/// Height input screen with a wheel picker.
/// User selects their height in centimeters.
struct HeightStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    
    // Height range (100-220 cm)
    private let heightRange = Array(100...220)
    
    @State private var height: Int = 170
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                Text("Your Height")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("We need your height to calculate your daily calorie needs.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            Spacer()
            
            // Height picker
            VStack(spacing: 16) {
                // Visual height indicator
                heightVisualization
                
                Picker("Height", selection: $height) {
                    ForEach(heightRange, id: \.self) { h in
                        Text("\(h) cm")
                            .tag(h)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 150)
                .clipped()
                
                // Display selected height
                HStack(spacing: 4) {
                    Text("\(height)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("cm")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                
                // Feet/inches conversion (for reference)
                Text(heightInFeetAndInches)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Navigation
            VStack(spacing: 12) {
                Button(action: {
                    // Save height
                    coordinator.updateData { data in
                        data.heightCm = Double(height)
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
            if let existing = coordinator.collectedData.heightCm {
                height = Int(existing)
            }
        }
    }
    
    // MARK: - Height Visualization
    
    private var heightVisualization: some View {
        // Simple visual indicator showing relative height
        let normalizedHeight = Double(height - 100) / 120.0 // 100-220 range normalized to 0-1
        let barHeight = 20 + normalizedHeight * 60 // 20-80 points
        
        return HStack(alignment: .bottom, spacing: 8) {
            // Height bar
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.accentColor)
                .frame(width: 24, height: CGFloat(barHeight))
            
            // Person icon
            Image(systemName: "figure.stand")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
        }
        .frame(height: 80)
    }
    
    // MARK: - Height Conversion
    
    private var heightInFeetAndInches: String {
        let totalInches = Double(height) / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return "(\(feet)'\(inches)\")"
    }
}

// MARK: - Preview

#if DEBUG
struct HeightStepView_Previews: PreviewProvider {
    static var previews: some View {
        HeightStepView(coordinator: OnboardingCoordinator())
    }
}
#endif




