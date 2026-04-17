import SwiftUI

/// Factory view that produces step views based on current coordinator state.
///
/// This is the main container for the onboarding flow. It:
/// 1. Reads current step from coordinator
/// 2. Uses @ViewBuilder switch to produce the correct step view
/// 3. Passes advancement closures to step views
///
/// Step views don't need to know what comes next - they just call
/// `onAdvance(.next)` and the coordinator handles the rest.
struct OnboardingContainerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var coordinator = OnboardingCoordinator()
    
    var body: some View {
        VStack {
            // Progress indicator at top
            OnboardingProgressView(
                currentStep: coordinator.currentStepNumber,
                totalSteps: coordinator.totalSteps,
                progress: coordinator.progress
            )
            .padding(.horizontal)
            .padding(.top)
            
            // Current step content
            stepView(for: coordinator.currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.3), value: coordinator.currentStep)
            
            Spacer()
        }
        .onAppear {
            // Set temporary user flag before starting
            coordinator.isTemporaryUser = appState.isTemporaryUser
            print("[OnboardingContainerView] isTemporaryUser: \(coordinator.isTemporaryUser)")
            
            // Start onboarding and pre-fill data if user is returning
            if let user = appState.currentUser, user.hasHealthData {
                let existingData = user.toOnboardingData()
                coordinator.collectedData.merge(with: existingData)
                print("[OnboardingContainerView] Pre-filled with existing user data")
            }
            coordinator.start()
        }
        .onChange(of: coordinator.isCompleted) { completed in
            if completed {
                handleOnboardingComplete()
            }
        }
    }
    
    // MARK: - Step Factory
    
    /// Factory method that produces the appropriate view for each step type.
    /// Add new steps here when extending the onboarding flow.
    @ViewBuilder
    private func stepView(for step: OnboardingStepType) -> some View {
        switch step {
        case .aboutApp:
            AboutAppStepView(coordinator: coordinator)
            
        case .healthKit:
            HealthKitStepView(coordinator: coordinator)

        case .personalInfo:
            PersonalInfoStepView(coordinator: coordinator)

        case .activityLevel:
            ActivityLevelStepView(coordinator: coordinator)
            
        case .weight:
            WeightStepView(coordinator: coordinator)
            
        case .height:
            HeightStepView(coordinator: coordinator)
            
        case .createAccount:
            CreateAccountStepView(coordinator: coordinator)
            
        case .ready:
            ReadyStepView(coordinator: coordinator)
        }
    }
    
    // MARK: - Completion Handler
    
    private func handleOnboardingComplete() {
        print("[OnboardingContainerView] Onboarding complete, syncing data...")
        
        // Save completion to UserDefaults
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
        
        // TODO: Sync collected data to backend
        // The coordinator.collectedData contains all the info we need
        
        // Trigger AppState update to navigate away from onboarding
        appState.objectWillChange.send()
    }
}

// MARK: - Progress View

/// Shows progress through onboarding steps
struct OnboardingProgressView: View {
    let currentStep: Int
    let totalSteps: Int
    let progress: Double
    
    var body: some View {
        VStack(spacing: DSSpacing.sm) {
            // Step indicator
            Text("Step \(currentStep) of \(totalSteps)")
                .font(.dsCaption)
                .foregroundColor(DSColors.textSecondary)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: DSCornerRadius.xs)
                        .fill(DSColors.textSecondary.opacity(0.2))
                        .frame(height: 4)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: DSCornerRadius.xs)
                        .fill(DSColors.primary)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Placeholder Step View

/// Temporary placeholder view for steps that haven't been implemented yet.
/// Shows the step name, navigation buttons, and debug info.
struct PlaceholderStepView: View {
    let step: OnboardingStepType
    @ObservedObject var coordinator: OnboardingCoordinator
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: DSSpacing.xl) {
            Spacer()
            
            // Step content
            VStack(spacing: DSSpacing.md) {
                Text(title)
                    .font(.dsTitle1)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.dsBody)
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DSSpacing.xl)
            
            // Debug info
            #if DEBUG
            debugInfoView
            #endif
            
            Spacer()
            
            // Navigation buttons
            navigationButtons
                .padding(.horizontal, DSSpacing.lg)
                .padding(.bottom, DSSpacing.xl)
        }
    }
    
    // MARK: - Debug Info
    
    #if DEBUG
    private var debugInfoView: some View {
        VStack(spacing: DSSpacing.sm) {
            Text("🔧 Debug Info")
                .font(.dsCaption)
                .fontWeight(.semibold)
            
            Text("Step: \(step.title) (\(step.rawValue))")
                .font(.dsCaption)
                .foregroundColor(DSColors.textSecondary)
            
            Text("Can skip: \(step.canSkip ? "Yes" : "No")")
                .font(.dsCaption)
                .foregroundColor(DSColors.textSecondary)
            
            Text("Is last: \(step.isLast ? "Yes" : "No")")
                .font(.dsCaption)
                .foregroundColor(DSColors.textSecondary)
            
            // Quick jump buttons
            HStack(spacing: DSSpacing.sm) {
                ForEach(OnboardingStepType.allCases) { jumpStep in
                    Button(action: {
                        coordinator.goToStep(jumpStep)
                    }) {
                        Text("\(jumpStep.rawValue)")
                            .font(.dsCaption)
                            .frame(width: 24, height: 24)
                            .background(jumpStep == step ? DSColors.primary : DSColors.textSecondary.opacity(0.2))
                            .foregroundColor(jumpStep == step ? DSColors.textInverted : DSColors.textPrimary)
                            .cornerRadius(DSCornerRadius.xs)
                    }
                }
            }
            .padding(.top, DSSpacing.sm)
        }
        .padding()
        .background(DSColors.textSecondary.opacity(0.1))
        .cornerRadius(DSCornerRadius.md)
        .padding(.horizontal)
    }
    #endif
    
    // MARK: - Navigation
    
    private var navigationButtons: some View {
        VStack(spacing: DSSpacing.smd) {
            // Primary action button
            Button(action: {
                withAnimation {
                    if step.isLast {
                        _ = coordinator.advance(.complete)
                    } else {
                        _ = coordinator.advance(.next)
                    }
                }
            }) {
                Text(step.isLast ? "Complete" : "Continue")
                    .font(.dsHeadline)
                    .foregroundColor(DSColors.textInverted)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DSColors.primary)
                    .cornerRadius(DSCornerRadius.md)
            }
            
            // Secondary actions (skip / back)
            HStack {
                if coordinator.canGoBack {
                    Button(action: {
                        withAnimation {
                            _ = coordinator.advance(.goBack)
                        }
                    }) {
                        Text("Back")
                            .font(.dsSubheadline)
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
                
                Spacer()
                
                if step.canSkip && !step.isLast {
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
        }
    }
}

// MARK: - Previews

struct OnboardingContainerView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingContainerView()
            .environmentObject(AppState())
    }
}


