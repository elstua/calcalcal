import SwiftUI

/// Welcome screen - first screen after sign-in.
/// Shows a greeting and sets the tone for the onboarding experience.
struct WelcomeStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App icon/illustration placeholder
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 160, height: 160)
                
                Image(systemName: "leaf.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.green)
            }
            
            // Welcome text
            VStack(spacing: 16) {
                Text("Welcome to Calcalcal!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Let's set up your profile to personalize your calorie tracking experience.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            // Continue button
            Button(action: {
                withAnimation {
                    _ = coordinator.advance(.next)
                }
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
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


