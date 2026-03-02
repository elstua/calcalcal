import SwiftUI

/// Barrel-style animated number display combining vertical slide with blur,
/// like native iOS picker/clock animations. Each changed digit rolls through
/// with motion blur while unchanged digits stay static.
struct CalorieBarrelView: View {
    let value: Int?
    let font: Font
    let color: Color

    @State private var displayedDigits: [Int] = []
    @State private var previousDigits: [Int?] = []
    @State private var animationProgress: [CGFloat] = [] // 0 = old visible, 1 = new visible
    @State private var isIncreasing: Bool = true
    @State private var animationTask: Task<Void, Never>? = nil

    private let slideHeight: CGFloat = 52
    private let baseDuration: Double = 0.35
    private let maxBlur: CGFloat = 6

    var body: some View {
        HStack(spacing: 0) {
            if displayedDigits.isEmpty {
                Text("—")
                    .font(font)
                    .foregroundColor(color)
            } else {
                ForEach(Array(displayedDigits.enumerated()), id: \.offset) { index, digit in
                    let prev: Int? = index < previousDigits.count ? previousDigits[index] : nil
                    let progress: CGFloat = index < animationProgress.count ? animationProgress[index] : 1.0

                    singleDigitView(digit: digit, previous: prev, progress: progress)
                }
            }
        }
        .frame(height: slideHeight)
        .clipped()
        .onChange(of: value) { _, newValue in
            triggerAnimation(to: newValue)
        }
        .onAppear {
            displayedDigits = digitsFrom(value)
            animationProgress = Array(repeating: 1.0, count: displayedDigits.count)
        }
    }

    /// Single digit cell — slides + blurs old digit out, slides + blurs new digit in.
    private func singleDigitView(digit: Int, previous: Int?, progress: CGFloat) -> some View {
        let direction: CGFloat = isIncreasing ? -1 : 1
        // Blur peaks in the middle of the transition (bell curve)
        let blurAmount = maxBlur * sin(progress * .pi)

        return ZStack {
            // Old digit — slides away + blurs
            if let prev = previous, progress < 1.0 {
                digitText(prev)
                    .offset(y: progress * slideHeight * direction)
                    .blur(radius: blurAmount)
                    .opacity(Double(1.0 - progress))
            }

            // New digit — slides in from opposite side + blurs
            digitText(digit)
                .offset(y: progress < 1.0 ? (progress - 1.0) * slideHeight * direction : 0)
                .blur(radius: progress < 1.0 ? blurAmount : 0)
                .opacity(progress < 1.0 ? Double(progress) : 1.0)
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

    private func triggerAnimation(to newValue: Int?) {
        animationTask?.cancel()

        let oldDigits = displayedDigits
        let newDigits = digitsFrom(newValue)

        // Determine direction
        let oldVal = oldDigits.isEmpty ? 0 : Int(oldDigits.map { "\($0)" }.joined()) ?? 0
        let newVal = newValue ?? 0
        isIncreasing = newVal >= oldVal

        // Update displayed digits
        displayedDigits = newDigits

        // Pad old digits to align with new (right-aligned)
        let lengthDiff = newDigits.count - oldDigits.count
        let paddedOld: [Int?]
        if lengthDiff > 0 {
            paddedOld = Array(repeating: nil as Int?, count: lengthDiff) + oldDigits.map { Optional($0) }
        } else if lengthDiff < 0 {
            paddedOld = Array(oldDigits.suffix(newDigits.count)).map { Optional($0) }
        } else {
            paddedOld = oldDigits.map { Optional($0) }
        }
        previousDigits = paddedOld

        // Find which digits changed
        var changedIndices: [Int] = []
        for i in 0..<newDigits.count {
            let old = i < paddedOld.count ? paddedOld[i] : nil
            if old != newDigits[i] {
                changedIndices.append(i)
            }
        }

        // Reset progress for changed digits
        animationProgress = (0..<newDigits.count).map { i in
            changedIndices.contains(i) ? 0.0 : 1.0
        }

        // Staggered animation — rightmost first
        let staggerDelay: Double = 0.04
        for (staggerIndex, digitIndex) in changedIndices.reversed().enumerated() {
            let delay = Double(staggerIndex) * staggerDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: baseDuration)) {
                    if digitIndex < animationProgress.count {
                        animationProgress[digitIndex] = 1.0
                    }
                }
            }
        }

        // Clean up
        let totalDuration = baseDuration + Double(changedIndices.count) * staggerDelay + 0.05
        animationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(totalDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            previousDigits = Array(repeating: nil, count: displayedDigits.count)
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
