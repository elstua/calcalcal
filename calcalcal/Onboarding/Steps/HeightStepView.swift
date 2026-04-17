import SwiftUI

/// Height input screen with a wheel picker.
/// User selects their height in centimeters.
struct HeightStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    
    // Height range (100-220 cm)
    private let heightRange = Array(100...220)
    
    @State private var height: Int = 170
    
    var body: some View {
        VStack(spacing: DSSpacing.xl) {
            // Header
            VStack(spacing: DSSpacing.smd) {
                Text("Your Height")
                    .font(.dsTitle1)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("We need your height to calculate your daily calorie needs.")
                    .font(.dsBody)
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.top, DSSpacing.md)
            
            Spacer()
            
            // Height picker
            VStack(spacing: DSSpacing.md) {
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
                HStack(spacing: DSSpacing.xs) {
                    Text("\(height)")
                        .font(.dsLargeNumber)
                    Text("cm")
                        .font(.dsTitle2)
                        .foregroundColor(DSColors.textSecondary)
                }
                
                // Feet/inches conversion (for reference)
                Text(heightInFeetAndInches)
                    .font(.dsSubheadline)
                    .foregroundColor(DSColors.textSecondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.xl)
                    .fill(DSColors.surfaceSecondary)
            )
            .padding(.horizontal, DSSpacing.lg)
            
            Spacer()
            
            // Navigation
            VStack(spacing: DSSpacing.smd) {
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
        
        return HStack(alignment: .bottom, spacing: DSSpacing.sm) {
            // Height bar
            RoundedRectangle(cornerRadius: DSCornerRadius.xs)
                .fill(DSColors.primary)
                .frame(width: 24, height: CGFloat(barHeight))
            
            // Person icon
            Image(systemName: "figure.stand")
                .font(Font.dsCustom(weight: .regular, size: 40))
                .foregroundColor(DSColors.primary)
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





