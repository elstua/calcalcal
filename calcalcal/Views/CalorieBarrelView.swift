import SwiftUI

/// A barrel/slot-machine style animated number display.
/// Numbers slide up or down when the value changes, with direction
/// depending on whether the new value is higher or lower.
struct CalorieBarrelView: View {
    let value: Int?
    let font: Font
    let color: Color

    @State private var displayedValue: Int? = nil
    @State private var previousValue: Int? = nil
    @State private var animationOffset: CGFloat = 0
    @State private var isAnimating: Bool = false
    @State private var slideDirection: CGFloat = 1 // 1 = up (increase), -1 = down (decrease)
    @State private var animationTask: Task<Void, Never>? = nil

    private let slideHeight: CGFloat = 52
    private let animationDuration: Double = 0.35

    var body: some View {
        ZStack {
            if isAnimating, let prev = previousValue {
                // Old number — slides out
                numberText(for: prev)
                    .offset(y: animationOffset * slideDirection)
                    .opacity(1.0 - abs(animationOffset / slideHeight))
            }

            // Current number — slides in during animation, static otherwise
            numberText(for: displayedValue)
                .offset(y: isAnimating ? (animationOffset - slideHeight) * slideDirection : 0)
                .opacity(isAnimating ? abs(animationOffset / slideHeight) : 1.0)
        }
        .clipped()
        .frame(height: slideHeight)
        .onChange(of: value) { _, newValue in
            triggerBarrelAnimation(to: newValue)
        }
        .onAppear {
            displayedValue = value
        }
    }

    private func numberText(for val: Int?) -> some View {
        Text(val.map { "\($0)" } ?? "—")
            .font(font)
            .foregroundColor(color)
            .monospacedDigit()
    }

    private func triggerBarrelAnimation(to newValue: Int?) {
        // Cancel any in-flight animation
        animationTask?.cancel()

        // If already animating, snap to current displayed value
        if isAnimating {
            withAnimation(.none) {
                animationOffset = 0
                isAnimating = false
            }
        }

        // Determine direction
        let oldVal = displayedValue ?? 0
        let newVal = newValue ?? 0
        slideDirection = newVal >= oldVal ? 1 : -1

        // Set up state
        previousValue = displayedValue
        displayedValue = newValue
        animationOffset = 0
        isAnimating = true

        // Animate
        withAnimation(.easeOut(duration: animationDuration)) {
            animationOffset = slideHeight
        }

        // Clean up after animation
        animationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(animationDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            isAnimating = false
            animationOffset = 0
            previousValue = nil
        }
    }
}

#if DEBUG
struct CalorieBarrelView_Previews: PreviewProvider {
    static var previews: some View {
        CalorieBarrelPreviewContainer()
            .padding()
    }
}

private struct CalorieBarrelPreviewContainer: View {
    @State private var calories: Int = 1250

    var body: some View {
        VStack(spacing: 24) {
            CalorieBarrelView(
                value: calories,
                font: .dsLargeNumber,
                color: DSColors.primary
            )

            HStack(spacing: 16) {
                Button("-100") { calories -= 100 }
                Button("+100") { calories += 100 }
                Button("+1") { calories += 1 }
            }
        }
    }
}
#endif
