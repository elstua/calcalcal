import SwiftUI

/// HealthKit permission screen - currently mocked.
/// Will integrate with actual HealthKit in a future iteration.
struct HealthKitStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var permissionRequested = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // HealthKit icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 140, height: 140)
                
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
            }
            
            // Title and description
            VStack(spacing: 16) {
                Text("Connect Health Data")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Sync with Apple Health to automatically import your weight, activity, and other health metrics.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Permission status indicator
            if permissionRequested {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("HealthKit access requested")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
            
            Spacer()
            
            // Buttons
            VStack(spacing: 12) {
                // Request permission button (mocked)
                Button(action: {
                    // TODO: Implement actual HealthKit permission request
                    withAnimation {
                        permissionRequested = true
                        coordinator.updateData { data in
                            data.healthKitAuthorized = true
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text(permissionRequested ? "Permission Granted" : "Connect Apple Health")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(permissionRequested ? Color.green : Color.red)
                    .cornerRadius(12)
                }
                .disabled(permissionRequested)
                
                // Continue button
                Button(action: {
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
                
                // Skip and back buttons
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
                        Text("Skip for now")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct HealthKitStepView_Previews: PreviewProvider {
    static var previews: some View {
        HealthKitStepView(coordinator: OnboardingCoordinator())
    }
}
#endif

