import SwiftUI
import HealthKit

/// HealthKit permission screen that integrates with Apple Health.
/// Shows Apple's native permission sheet when user taps "Connect Apple Health".
struct HealthKitStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @StateObject private var healthKitManager = HealthKitManager.shared
    
    @State private var authorizationState: AuthorizationState = .notRequested
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    enum AuthorizationState {
        case notRequested
        case requesting
        case authorized
        case denied
        case unavailable
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // HealthKit icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor.opacity(0.15))
                    .frame(width: 140, height: 140)
                
                Image(systemName: iconName)
                    .font(.system(size: 60))
                    .foregroundColor(iconColor)
            }
            
            // Title and description
            VStack(spacing: 16) {
                Text("Connect Health Data")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(descriptionText)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Status indicator
            statusIndicator
            
            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            // Buttons
            VStack(spacing: 12) {
                // Request permission button
                Button(action: requestHealthKitPermission) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: buttonIcon)
                            Text(buttonText)
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(buttonBackgroundColor)
                    .cornerRadius(12)
                }
                .disabled(isButtonDisabled)
                
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
        .onAppear {
            checkHealthKitAvailability()
        }
    }
    
    // MARK: - Computed Properties
    
    private var iconName: String {
        switch authorizationState {
        case .authorized:
            return "checkmark.circle.fill"
        case .denied, .unavailable:
            return "xmark.circle.fill"
        default:
            return "heart.fill"
        }
    }
    
    private var iconColor: Color {
        switch authorizationState {
        case .authorized:
            return .green
        case .denied, .unavailable:
            return .gray
        default:
            return .red
        }
    }
    
    private var iconBackgroundColor: Color {
        switch authorizationState {
        case .authorized:
            return .green
        case .denied, .unavailable:
            return .gray
        default:
            return .red
        }
    }
    
    private var descriptionText: String {
        switch authorizationState {
        case .unavailable:
            return "HealthKit is not available on this device. You can still use the app by entering your health data manually."
        case .authorized:
            return "Great! Your health data has been synced. We've imported your weight, height, and other available metrics."
        case .denied:
            return "HealthKit access was denied. You can enable it later in Settings, or enter your health data manually."
        default:
            return "Sync with Apple Health to automatically import your weight, height, and other health metrics."
        }
    }
    
    private var buttonText: String {
        switch authorizationState {
        case .unavailable:
            return "Not Available"
        case .authorized:
            return "Connected"
        case .denied:
            return "Access Denied"
        case .requesting:
            return "Requesting..."
        default:
            return "Connect Apple Health"
        }
    }
    
    private var buttonIcon: String {
        switch authorizationState {
        case .authorized:
            return "checkmark"
        case .denied, .unavailable:
            return "xmark"
        default:
            return "heart.fill"
        }
    }
    
    private var buttonBackgroundColor: Color {
        switch authorizationState {
        case .authorized:
            return .green
        case .denied, .unavailable:
            return .gray
        default:
            return .red
        }
    }
    
    private var isButtonDisabled: Bool {
        switch authorizationState {
        case .unavailable, .authorized, .requesting:
            return true
        default:
            return isLoading
        }
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        switch authorizationState {
        case .authorized:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("HealthKit connected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
        case .denied:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Permission denied")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            
        case .unavailable:
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.gray)
                Text("HealthKit unavailable")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Actions
    
    private func checkHealthKitAvailability() {
        if !healthKitManager.isAvailable {
            authorizationState = .unavailable
        }
    }
    
    private func requestHealthKitPermission() {
        guard healthKitManager.isAvailable else {
            authorizationState = .unavailable
            return
        }
        
        isLoading = true
        authorizationState = .requesting
        errorMessage = nil
        
        Task {
            do {
                // Request both read and write permissions at once
                // This shows Apple's native HealthKit permission sheet
                let authorized = try await healthKitManager.requestAllPermissions()
                
                if authorized {
                    // Read health data and update onboarding data
                    await readAndUpdateHealthData()
                    
                    await MainActor.run {
                        withAnimation {
                            authorizationState = .authorized
                            coordinator.updateData { data in
                                data.healthKitAuthorized = true
                            }
                        }
                    }
                } else {
                    await MainActor.run {
                        withAnimation {
                            authorizationState = .denied
                            coordinator.updateData { data in
                                data.healthKitAuthorized = false
                            }
                        }
                    }
                }
            } catch {
                print("[HealthKitStep] Error requesting permissions: \(error.localizedDescription)")
                await MainActor.run {
                    withAnimation {
                        authorizationState = .denied
                        errorMessage = error.localizedDescription
                        coordinator.updateData { data in
                            data.healthKitAuthorized = false
                        }
                    }
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    /// Read health data from HealthKit and update the onboarding data
    private func readAndUpdateHealthData() async {
        do {
            let (weight, height, gender, age) = try await healthKitManager.readAllHealthData()
            
            await MainActor.run {
                coordinator.updateData { data in
                    // Only update values that were successfully read
                    // Don't overwrite existing user-entered data
                    if let weight = weight, data.weightKg == nil {
                        data.weightKg = weight
                        print("[HealthKitStep] Imported weight: \(weight) kg")
                    }
                    if let height = height, data.heightCm == nil {
                        data.heightCm = height
                        print("[HealthKitStep] Imported height: \(height) cm")
                    }
                    if let gender = gender, data.gender == nil {
                        data.gender = gender
                        print("[HealthKitStep] Imported gender: \(gender)")
                    }
                    if let age = age, data.age == nil {
                        data.age = age
                        print("[HealthKitStep] Imported age: \(age)")
                    }
                }
            }
        } catch {
            print("[HealthKitStep] Error reading health data: \(error.localizedDescription)")
            // Don't show error to user - partial data is acceptable
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
