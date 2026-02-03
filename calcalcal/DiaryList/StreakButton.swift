import SwiftUI
import UIKit
import Foundation

// MARK: - Droplet Configuration
/// Configuration for a single droplet at a specific streak state
struct DropletConfig {
    let width: CGFloat
    let height: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat
    let rotation: Double
    let opacity: Double
    let color: Color
}

// MARK: - Streak State Configuration
/// Complete configuration for a streak state (0-7+)
struct StreakStateConfig {
    let leftDroplet: DropletConfig?
    let rightDroplet: DropletConfig?
    let thirdDroplet: DropletConfig?
    let animationSpeed: Double
    let animationRange: ClosedRange<CGFloat>
    let rotationRange: ClosedRange<Double>
    let offsetRange: ClosedRange<CGFloat>
}

// MARK: - Extreme Animation Configuration
/// Configuration for the "insane" animation during barrel transitions
struct ExtremeAnimationConfig {
    let leftDroplet: DropletConfig
    let rightDroplet: DropletConfig
    let thirdDroplet: DropletConfig
    let animationSpeed: Double
    let animationRange: ClosedRange<CGFloat>
    let rotationRange: ClosedRange<Double>
    let offsetRange: ClosedRange<CGFloat>
    
    static let `default` = ExtremeAnimationConfig(
        leftDroplet: DropletConfig(
            width: 28,
            height: 48,
            offsetX: -16,
            offsetY: -17,
            rotation: -12,
            opacity: 1,
            color: DSColors.secondary
        ),
        rightDroplet: DropletConfig(
            width: 24,
            height: 48,
            offsetX: 0,
            offsetY: -16,
            rotation: 4,
            opacity: 1,
            color: DSColors.secondary
        ),
        thirdDroplet: DropletConfig(
            width: 24,
            height: 32,
            offsetX: 16,
            offsetY: -14,
            rotation: 16,
            opacity: 1,
            color: DSColors.secondary
        ),
        animationSpeed: 0.1,
        animationRange: 0.8...1,
        rotationRange: -24...20,
        offsetRange: 0...0
    )
}

// MARK: - Streak Button Configuration
/// Centralized configuration for all streak states
struct StreakButtonConfiguration {
    
    // MARK: - Default Configuration
    static let `default` = StreakButtonConfiguration()
    
    // MARK: - State Configurations
    let states: [Int: StreakStateConfig]
    
    // MARK: - Initialization
    init(states: [Int: StreakStateConfig]? = nil) {
        self.states = states ?? StreakButtonConfiguration.createDefaultStates()
    }
    
    // MARK: - Helper Methods
    func config(for streak: Int) -> StreakStateConfig {
        let normalizedStreak = min(streak, 7)
        return states[normalizedStreak] ?? states[0]!
    }
    
    // MARK: - Default State Creation
    private static func createDefaultStates() -> [Int: StreakStateConfig] {
        [
            0: StreakStateConfig(
                leftDroplet: nil,
                rightDroplet: nil,
                thirdDroplet: nil,
                animationSpeed: 0,
                animationRange: 0.9...1.1,
                rotationRange: -5...5,
                offsetRange: -2...2
            ),
            1: StreakStateConfig(
                leftDroplet: DropletConfig(
                    width: 18,
                    height: 24,
                    offsetX: -8,
                    offsetY: -9,
                    rotation: -24,
                    opacity: 1,
                    color: DSColors.secondary
                ),
                rightDroplet: DropletConfig(
                    width: 18,
                    height: 24,
                    offsetX: 0,
                    offsetY: -9,
                    rotation: -24,
                    opacity: 1,
                    color: DSColors.secondary
                ),
                thirdDroplet: nil,
                animationSpeed: 0.4,
                animationRange: 0.9...1.1,
                rotationRange: 0...0,
                offsetRange: 0...0
            ),
            2: StreakStateConfig(
                leftDroplet: DropletConfig(
                    width: 24,
                    height: 32,
                    offsetX: -12,
                    offsetY: -7,
                    rotation: -17,
                    opacity: 1,
                    color: DSColors.secondary
                ),
                rightDroplet: DropletConfig(
                    width: 17,
                    height: 24,
                    offsetX: -2,
                    offsetY: -10,
                    rotation: -9,
                    opacity: 1,
                    color: DSColors.secondary
                ),
                thirdDroplet: nil,
                animationSpeed: 0.3,
                animationRange: 0.9...1,
                rotationRange: 0...0,
                offsetRange: 0...0
            ),
            3: StreakStateConfig(
                leftDroplet: DropletConfig(
                    width: 26,
                    height: 32,
                    offsetX: -12,
                    offsetY: -7,
                    rotation: -17,
                    opacity: 1,
                    color: DSColors.secondary
                ),
                rightDroplet: DropletConfig(
                    width: 16,
                    height: 28,
                    offsetX: 4,
                    offsetY: -12,
                    rotation: -24,
                    opacity: 1,
                    color: DSColors.secondary
                ),
                thirdDroplet: nil,
                animationSpeed: 0.4,
                animationRange: 1...1.1,
                rotationRange: 0...0,
                offsetRange: 0...3
            ),
            4: StreakStateConfig(
                leftDroplet: DropletConfig(
                    width: 30,
                    height: 36,
                    offsetX: -13,
                    offsetY: -5,
                    rotation: -24,
                    opacity: 1,
                    color: DSColors.secondary
                ),
                rightDroplet: DropletConfig(
                    width: 26,
                    height: 32,
                    offsetX: 0,
                    offsetY: -8,
                    rotation: -4,
                    opacity: 1,
                    color: DSColors.secondary
                ),
                thirdDroplet: DropletConfig(
                    width: 16,
                    height: 32,
                    offsetX: 16,
                    offsetY: -4,
                    rotation: 3,
                    opacity: 1,
                    color: DSColors.secondary
                ),
                animationSpeed: 0.4,
                animationRange: 0.9...1.1,
                rotationRange: -5...5,
                offsetRange: -2...2
            ),
            
            5: StreakStateConfig(
                leftDroplet: DropletConfig(
                    width: 24,
                    height: 40,
                    offsetX: -13,
                    offsetY: -5,
                    rotation: -24,
                    opacity: 1,
                    color: DSColors.secondary
                ),
                rightDroplet: DropletConfig(
                    width: 26,
                    height: 40,
                    offsetX: 0,
                    offsetY: -6,
                    rotation: -4,
                    opacity: 1,
                    color: DSColors.secondary
                ),
                thirdDroplet: DropletConfig(
                    width: 16,
                    height: 32,
                    offsetX: 16,
                    offsetY: -4,
                    rotation: 3,
                    opacity: 1,
                    color: DSColors.secondary
                ),
                animationSpeed: 0.4,
                animationRange: 1...1.1,
                rotationRange: -5...5,
                offsetRange: -2...2
            ),
            
            6: StreakStateConfig(
                leftDroplet: DropletConfig(
                    width: 32,
                    height: 40,
                    offsetX: -13,
                    offsetY: -5,
                    rotation: -24,
                    opacity: 1,
                    color: DSColors.secondary
                ),
                rightDroplet: DropletConfig(
                    width: 26,
                    height: 40,
                    offsetX: 0,
                    offsetY: -6,
                    rotation: -8,
                    opacity: 1,
                    color: DSColors.secondary
                ),
                thirdDroplet: DropletConfig(
                    width: 16,
                    height: 32,
                    offsetX: 16,
                    offsetY: -4,
                    rotation: -3,
                    opacity: 1,
                    color: DSColors.secondary
                ),
                animationSpeed: 0.4,
                animationRange: 1...1.1,
                rotationRange: -5...5,
                offsetRange: -2...2
            ),
            
            7: StreakStateConfig(
                leftDroplet: DropletConfig(
                    width: 24,
                    height: 40,
                    offsetX: -13,
                    offsetY: -9,
                    rotation: -24,
                    opacity: 1,
                    color: DSColors.secondary
                ),
                rightDroplet: DropletConfig(
                    width: 26,
                    height: 40,
                    offsetX: 0,
                    offsetY: -8,
                    rotation: -8,
                    opacity: 1,
                    color: DSColors.secondary
                ),
                thirdDroplet: DropletConfig(
                    width: 16,
                    height: 32,
                    offsetX: 16,
                    offsetY: -7,
                    rotation: -16,
                    opacity: 1,
                    color: DSColors.secondary
                ),
                animationSpeed: 0.3,
                animationRange: 1...1.2,
                rotationRange: -5...5,
                offsetRange: -2...2
            ),
        ]
    }
}

// MARK: - Streak Button
struct StreakButton: View {
    let streak: Int
    let isAddingToStreak: Bool
    let previousStreak: Int
    let action: () -> Void
    let configuration: StreakButtonConfiguration
    
    // Animation states
    @State private var leftDropletScale: CGFloat = 1.0
    @State private var rightDropletScale: CGFloat = 1.0
    @State private var thirdDropletScale: CGFloat = 1.0
    @State private var leftDropletRotation: Double = 0
    @State private var rightDropletRotation: Double = 0
    @State private var thirdDropletRotation: Double = 0
    @State private var leftDropletOffset: CGFloat = 0
    @State private var rightDropletOffset: CGFloat = 0
    @State private var thirdDropletOffset: CGFloat = 0
    
    // Number barrel animation states
    @State private var numberOffset: CGFloat = 0
    @State private var isAnimatingNumber: Bool = false
    
    // Animation timer
    @State private var animationTimer: Timer? = nil
    @State private var isInInsaneMode: Bool = false
    
    // MARK: - Initialization
    init(
        streak: Int,
        isAddingToStreak: Bool = false,
        previousStreak: Int? = nil,
        configuration: StreakButtonConfiguration = .default,
        action: @escaping () -> Void
    ) {
        self.streak = streak
        self.isAddingToStreak = isAddingToStreak
        self.previousStreak = previousStreak ?? max(0, streak - 1)
        self.configuration = configuration
        self.action = action
    }
    
    // MARK: - Computed Properties
    private var currentConfig: StreakStateConfig {
        configuration.config(for: streak)
    }
    
    private var displayStreak: Int {
        isAnimatingNumber ? previousStreak : streak
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Droplets layer
                if streak > 0 || isAddingToStreak {
                    dropletsLayer
                }
                
                // Text layer with barrel animation
                numberDisplay
                    .zIndex(1)
            }
            .frame(height: 24)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(streak == 0 ? Color.clear : DSColors.secondary)
                    .overlay(
                        Capsule()
                            .stroke(streak == 0 ? DSColors.secondary : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .onAppear {
            // Always restart animation on appear to ensure it works after app reopen
            stopAnimation()
            startAnimation()
            if isAddingToStreak {
                performBarrelAnimation()
            }
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: streak) { newStreak in
            // Restart animation whenever streak changes (even to same value after view recreation)
            if !isAnimatingNumber {
                stopAnimation()
                startAnimation()
            }
        }
        .onChange(of: isAddingToStreak) { newValue in
            if newValue {
                performBarrelAnimation()
            }
        }
        // Use task to ensure animation continues even when view is recreated
        .task {
            // Small delay to ensure view is fully mounted
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            if animationTimer == nil && streak > 0 {
                startAnimation()
            }
        }
    }
    
    // MARK: - Number Display with Barrel Animation
    private var numberDisplay: some View {
        ZStack {
            // Previous number (always present as a separate view)
            Text("\(previousStreak)")
                .dsTypography(.body)
                .foregroundColor(streak == 0 ? DSColors.secondary : .white)
                .offset(y: isAnimatingNumber ? numberOffset : 0)
                .opacity(isAnimatingNumber ? 1.0 - (numberOffset / 30.0) : 0)
            
            // New number (always present as a separate view)
            Text("\(streak)")
                .dsTypography(.body)
                .foregroundColor(streak == 0 ? DSColors.secondary : .white)
                .offset(y: isAnimatingNumber ? numberOffset - 30 : 0)
                .opacity(isAnimatingNumber ? numberOffset / 30.0 : 1.0)
        }
        .clipped()
        .frame(height: 32)
    }
    
    // MARK: - Barrel Animation
    private func performBarrelAnimation() {
        isAnimatingNumber = true
        isInInsaneMode = true
        
        // Start from top position
        numberOffset = 0
        
        // Start extreme droplet animation
        startExtremeAnimation()
        
        // Animate both numbers sliding down
        withAnimation(.easeIn(duration: 1)) {
            numberOffset = 56
        }
        
        // After animation completes, transition to normal state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                self.isAnimatingNumber = false
                self.numberOffset = 0
            }
            
            // Transition from extreme to normal animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.isInInsaneMode = false
                self.stopAnimation()
                self.startAnimation()
            }
        }
    }
    
    // MARK: - Extreme Animation Mode
    private func startExtremeAnimation() {
        let extremeConfig = ExtremeAnimationConfig.default
        
        animationTimer?.invalidate()
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: extremeConfig.animationSpeed, repeats: true) { _ in
            withAnimation(.easeInOut(duration: extremeConfig.animationSpeed)) {
                self.leftDropletRotation = Double.random(in: extremeConfig.rotationRange)
                self.leftDropletScale = CGFloat.random(in: extremeConfig.animationRange)
                self.leftDropletOffset = CGFloat.random(in: extremeConfig.offsetRange)
                
                self.rightDropletRotation = Double.random(in: extremeConfig.rotationRange)
                self.rightDropletScale = CGFloat.random(in: extremeConfig.animationRange)
                self.rightDropletOffset = CGFloat.random(in: extremeConfig.offsetRange)
                
                self.thirdDropletRotation = Double.random(in: extremeConfig.rotationRange)
                self.thirdDropletScale = CGFloat.random(in: extremeConfig.animationRange)
                self.thirdDropletOffset = CGFloat.random(in: extremeConfig.offsetRange)
            }
        }
        
        // Ensure timer runs on main run loop to keep animations active
        if let timer = animationTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    // MARK: - Droplets Layer
    private var dropletsLayer: some View {
        ZStack {
            if isInInsaneMode {
                // Use extreme animation config during barrel animation
                extremeDropletsLayer
            } else {
                // Use normal state config
                normalDropletsLayer
            }
        }
    }
    
    private var normalDropletsLayer: some View {
        ZStack {
            if let leftConfig = currentConfig.leftDroplet {
                StreakDropletShape()
                    .fill(leftConfig.color)
                    .frame(width: leftConfig.width, height: leftConfig.height)
                    .scaleEffect(leftDropletScale)
                    .rotationEffect(.degrees(leftDropletRotation + leftConfig.rotation))
                    .offset(x: leftConfig.offsetX + leftDropletOffset, y: leftConfig.offsetY)
                    .opacity(leftConfig.opacity)
            }
            
            if let rightConfig = currentConfig.rightDroplet {
                StreakDropletShape()
                    .fill(rightConfig.color)
                    .frame(width: rightConfig.width, height: rightConfig.height)
                    .scaleEffect(rightDropletScale)
                    .rotationEffect(.degrees(rightDropletRotation + rightConfig.rotation))
                    .offset(x: rightConfig.offsetX + rightDropletOffset, y: rightConfig.offsetY)
                    .opacity(rightConfig.opacity)
            }
            
            if let thirdConfig = currentConfig.thirdDroplet {
                StreakDropletShape()
                    .fill(thirdConfig.color)
                    .frame(width: thirdConfig.width, height: thirdConfig.height)
                    .scaleEffect(thirdDropletScale)
                    .rotationEffect(.degrees(thirdDropletRotation + thirdConfig.rotation))
                    .offset(x: thirdConfig.offsetX + thirdDropletOffset, y: thirdConfig.offsetY)
                    .opacity(thirdConfig.opacity)
            }
        }
    }
    
    private var extremeDropletsLayer: some View {
        let extremeConfig = ExtremeAnimationConfig.default
        
        return ZStack {
            // Left droplet
            StreakDropletShape()
                .fill(extremeConfig.leftDroplet.color)
                .frame(width: extremeConfig.leftDroplet.width, height: extremeConfig.leftDroplet.height)
                .scaleEffect(leftDropletScale)
                .rotationEffect(.degrees(leftDropletRotation + extremeConfig.leftDroplet.rotation))
                .offset(x: extremeConfig.leftDroplet.offsetX + leftDropletOffset, y: extremeConfig.leftDroplet.offsetY)
                .opacity(extremeConfig.leftDroplet.opacity)
            
            // Right droplet
            StreakDropletShape()
                .fill(extremeConfig.rightDroplet.color)
                .frame(width: extremeConfig.rightDroplet.width, height: extremeConfig.rightDroplet.height)
                .scaleEffect(rightDropletScale)
                .rotationEffect(.degrees(rightDropletRotation + extremeConfig.rightDroplet.rotation))
                .offset(x: extremeConfig.rightDroplet.offsetX + rightDropletOffset, y: extremeConfig.rightDroplet.offsetY)
                .opacity(extremeConfig.rightDroplet.opacity)
            
            // Third droplet
            StreakDropletShape()
                .fill(extremeConfig.thirdDroplet.color)
                .frame(width: extremeConfig.thirdDroplet.width, height: extremeConfig.thirdDroplet.height)
                .scaleEffect(thirdDropletScale)
                .rotationEffect(.degrees(thirdDropletRotation + extremeConfig.thirdDroplet.rotation))
                .offset(x: extremeConfig.thirdDroplet.offsetX + thirdDropletOffset, y: extremeConfig.thirdDroplet.offsetY)
                .opacity(extremeConfig.thirdDroplet.opacity)
        }
    }
    
    // MARK: - Normal Animation
    private func startAnimation() {
        guard streak > 0 && !isInInsaneMode else { return }
        
        // Stop any existing timer before starting a new one
        stopAnimation()
        
        let config = currentConfig
        
        withAnimation(.easeInOut(duration: 0.1)) {
            leftDropletScale = randomScale()
            rightDropletScale = randomScale()
            thirdDropletScale = randomScale()
        }
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: config.animationSpeed, repeats: true) { _ in
            self.animateDroplets()
        }
        
        // Ensure timer runs on main run loop to keep animations active
        if let timer = animationTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        animateDroplets()
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func animateDroplets() {
        guard !isInInsaneMode else { return }
        
        let config = currentConfig
        
        withAnimation(.easeInOut(duration: config.animationSpeed * 0.3)) {
            leftDropletRotation = Double.random(in: config.rotationRange)
            leftDropletScale = randomScale()
            leftDropletOffset = CGFloat.random(in: config.offsetRange)
        }
        
        withAnimation(.easeInOut(duration: config.animationSpeed * 0.3)) {
            rightDropletRotation = Double.random(in: config.rotationRange)
            rightDropletScale = randomScale()
            rightDropletOffset = CGFloat.random(in: config.offsetRange)
        }
        
        if currentConfig.thirdDroplet != nil {
            withAnimation(.easeInOut(duration: config.animationSpeed * 0.3)) {
                thirdDropletRotation = Double.random(in: config.rotationRange)
                thirdDropletScale = randomScale()
                thirdDropletOffset = CGFloat.random(in: config.offsetRange)
            }
        }
    }
    
    private func randomScale() -> CGFloat {
        CGFloat.random(in: currentConfig.animationRange)
    }
}

// MARK: - Scale Button Style
/// Button style that scales the button on press instead of changing opacity
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyle.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
struct StreakButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            StreakButton(streak: 0) {}
                .previewDisplayName("Streak 0 - Border Style")
            
            StreakButton(streak: 1) {}
                .previewDisplayName("Streak 1")
            
            StreakButton(streak: 2) {}
                .previewDisplayName("Streak 2")
            
            StreakButton(streak: 3) {}
                .previewDisplayName("Streak 3")
            
            StreakButton(streak: 4) {}
                .previewDisplayName("Streak 4")
            
            StreakButton(streak: 5) {}
                .previewDisplayName("Streak 5")
            
            StreakButton(streak: 6) {}
                .previewDisplayName("Streak 6")
            
            StreakButton(streak: 7) {}
                .previewDisplayName("Streak 7")
            
            StreakButton(streak: 1332) {}
                .previewDisplayName("Streak 1332")
            
            // Adding to streak animation preview
            StreakButton(streak: 5, isAddingToStreak: true, previousStreak: 4) {}
                .previewDisplayName("Adding to Streak - Animation")
            
            // Interactive preview - tap to increment streak
            StreakButtonInteractivePreview()
                .previewDisplayName("Interactive - Tap to Add Streak")
        }
        .padding()
        .background(DSColors.background)
    }
}

// MARK: - Interactive Preview
struct StreakButtonInteractivePreview: View {
    @State private var currentStreak: Int = 3
    @State private var isAdding: Bool = false
    @State private var previousStreak: Int = 3
    
    var body: some View {
        VStack(spacing: 32) {
            Text("Current Streak: \(currentStreak)")
                .dsTypography(.headline)
                .foregroundColor(DSColors.textPrimary)
            
            StreakButton(
                streak: currentStreak,
                isAddingToStreak: isAdding,
                previousStreak: previousStreak
            ) {
                // Trigger animation on tap
                guard !isAdding else { return }
                
                previousStreak = currentStreak
                isAdding = true
                
                // After animation completes, update the actual streak
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    currentStreak += 1
                    isAdding = false
                }
            }
            
            Text("Tap button to add streak")
                .dsTypography(.caption)
                .foregroundColor(DSColors.textSecondary)
        }
        .padding()
        .background(DSColors.surface)
        .cornerRadius(12)
    }
}
