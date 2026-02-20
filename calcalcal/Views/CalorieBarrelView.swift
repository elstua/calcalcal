import SwiftUI

/// A barrel/slot-machine style animated number display that animates each digit independently.
/// Digits that change roll up or down individually with staggered timing for a natural look.
struct CalorieBarrelView: View {
    let value: Int?
    let font: Font
    let color: Color

    @State private var displayedDigits: [Int] = []
    @State private var previousDigits: [Int] = []
    @State private var digitAnimating: [Bool] = []
    @State private var digitOffsets: [CGFloat] = []
    @State private var animationTask: Task<Void, Never>? = nil
    @State private var isIncreasing: Bool = true

    private let slideHeight: CGFloat = 52
    private let baseDuration: Double = 0.3

    var body: some View {
        HStack(spacing: 0) {
            if displayedDigits.isEmpty {
                singleDigitView(digit: nil, previous: nil, isAnimating: false, offset: 0)
            } else {
                ForEach(Array(displayedDigits.enumerated()), id: \.offset) { index, digit in
                    let prev = index < previousDigits.count ? previousDigits[index] : nil
                    let animating = index < digitAnimating.count ? digitAnimating[index] : false
                    let offset = index < digitOffsets.count ? digitOffsets[index] : 0

                    singleDigitView(
                        digit: digit,
                        previous: prev,
                        isAnimating: animating,
                        offset: offset
                    )
                }
            }
        }
        .frame(height: slideHeight)
        .clipped()
        .onChange(of: value) { _, newValue in
            triggerPerDigitAnimation(to: newValue)
        }
        .onAppear {
            displayedDigits = digitsFrom(value)
        }
    }

    private func singleDigitView(digit: Int?, previous: Int?, isAnimating: Bool, offset: CGFloat) -> some View {
        let direction: CGFloat = isIncreasing ? -1 : 1

        return ZStack {
            if isAnimating, let prev = previous {
                // Old digit — slides out
                digitText(prev)
                    .offset(y: offset * direction)
                    .opacity(1.0 - abs(offset / slideHeight))
            }

            if let digit = digit {
                // New digit — slides in during animation, static otherwise
                digitText(digit)
                    .offset(y: isAnimating ? (offset - slideHeight) * direction : 0)
                    .opacity(isAnimating ? abs(offset / slideHeight) : 1.0)
            } else {
                // Placeholder
                Text("—")
                    .font(font)
                    .foregroundColor(color)
            }
        }
        .frame(height: slideHeight)
        .clipped()
    }

    private func digitText(_ digit: Int) -> some View {
        Text("\(digit)")
            .font(font)
            .foregroundColor(color)
            .monospacedDigit()
    }

    private func digitsFrom(_ value: Int?) -> [Int] {
        guard let value = value, value >= 0 else { return [] }
        if value == 0 { return [0] }
        return String(value).compactMap { $0.wholeNumberValue }
    }

    private func triggerPerDigitAnimation(to newValue: Int?) {
        animationTask?.cancel()

        // Snap any in-flight animations
        for i in digitAnimating.indices {
            digitAnimating[i] = false
            digitOffsets[i] = 0
        }

        let oldDigits = displayedDigits
        let newDigits = digitsFrom(newValue)

        let oldVal = value.flatMap { _ in displayedDigits.isEmpty ? nil : Int(displayedDigits.map { "\($0)" }.joined()) } ?? 0
        let newVal = newValue ?? 0
        isIncreasing = newVal >= oldVal

        // Update displayed digits immediately (the animation will handle the visual transition)
        displayedDigits = newDigits
        previousDigits = oldDigits

        // Pad previous digits to match new length for per-digit animation
        let paddedPrevious = Array(repeating: Optional<Int>.none, count: max(0, newDigits.count - oldDigits.count))
            + oldDigits.map { Optional($0) }

        // Set up animation arrays
        digitAnimating = Array(repeating: false, count: newDigits.count)
        digitOffsets = Array(repeating: CGFloat(0), count: newDigits.count)

        // Pad previousDigits to match displayed count
        previousDigits = paddedPrevious.map { $0 ?? -1 }.suffix(newDigits.count).map { $0 }

        // Determine which digits changed and animate them with stagger
        var changedIndices: [Int] = []
        for i in 0..<newDigits.count {
            let oldIndex = i - (newDigits.count - oldDigits.count)
            let oldDigit = oldIndex >= 0 && oldIndex < oldDigits.count ? oldDigits[oldIndex] : -1
            if oldDigit != newDigits[i] || oldDigits.count != newDigits.count {
                changedIndices.append(i)
            }
        }

        // Animate changed digits with stagger (rightmost first for a natural barrel feel)
        let staggerDelay: Double = 0.04
        for (staggerIndex, digitIndex) in changedIndices.reversed().enumerated() {
            let delay = Double(staggerIndex) * staggerDelay
            digitAnimating[digitIndex] = true

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: baseDuration)) {
                    if digitIndex < digitOffsets.count {
                        digitOffsets[digitIndex] = slideHeight
                    }
                }
            }
        }

        // Clean up after all animations complete
        let totalDuration = baseDuration + Double(changedIndices.count) * staggerDelay + 0.05
        animationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(totalDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            for i in digitAnimating.indices {
                digitAnimating[i] = false
                digitOffsets[i] = 0
            }
            previousDigits = []
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
