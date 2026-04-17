import SwiftUI

/// Welcome screen - first screen after sign-in.
/// Shows a greeting and sets the tone for the onboarding experience.
struct WelcomeStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    
    var body: some View {
        VStack(spacing: DSSpacing.xxl) {
            Spacer()
            
            // App icon/illustration placeholder
            ZStack {
                Circle()
                    .fill(DSColors.success.opacity(0.15))
                    .frame(width: 160, height: 160)
                
                Image(systemName: "leaf.fill")
                    .font(Font.dsCustom(weight: .regular, size: 70))
                    .foregroundColor(DSColors.success)
            }
            
            // Welcome text
            VStack(spacing: DSSpacing.md) {
                Text("Welcome to Calcalcal!")
                    .font(.dsDisplay)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Let's set up your profile to personalize your calorie tracking experience.")
                    .font(.dsBody)
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSSpacing.xl)
            }
            
            Spacer()
            
            // Continue button
            Button(action: {
                withAnimation {
                    _ = coordinator.advance(.next)
                }
            }) {
                Text("Get Started")
                    .font(.dsHeadline)
                    .foregroundColor(DSColors.textInverted)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DSColors.success)
                    .cornerRadius(DSCornerRadius.md)
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.bottom, DSSpacing.xl)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct WelcomeStepView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeStepView(coordinator: OnboardingCoordinator())
    }
}
#endif





