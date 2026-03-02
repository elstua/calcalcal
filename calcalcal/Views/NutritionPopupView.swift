import SwiftUI

// MARK: - Macro ring colors (matching the mockup)

private enum MacroColor {
    /// Carbs — light blue / teal
    static let carbs = Color(hex: 0x5CB8C4)
    /// Protein — dark green
    static let protein = Color(hex: 0x3B8A5E)
    /// Fat — warm orange
    static let fat = Color(hex: 0xE0854A)
}

// MARK: - Custom macro shapes

/// Wavy / scalloped circle shape for Carbs.
private struct WavyCircleShape: Shape {
    /// Number of bumps around the perimeter.
    var bumps: Int = 16
    /// Bump amplitude as a fraction of the radius (0…1).
    var amplitude: CGFloat = 0.05

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) / 2
        let steps = bumps * 20 // smooth curve

        var path = Path()
        for i in 0...steps {
            let angle = CGFloat(i) / CGFloat(steps) * 2 * .pi
            let r = baseRadius * (1 - amplitude) + baseRadius * amplitude * cos(angle * CGFloat(bumps))
            let x = center.x + r * cos(angle - .pi / 2)
            let y = center.y + r * sin(angle - .pi / 2)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

/// Regular polygon shape for Proteins (octagon by default).
private struct PolygonShape: Shape {
    var sides: Int = 8

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()

        for i in 0..<sides {
            let angle = CGFloat(i) / CGFloat(sides) * 2 * .pi - .pi / 2
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Macro shape kind

private enum MacroShapeKind {
    case wavyCircle
    case octagon
    case roundedRect
}

// MARK: - Macro progress ring

/// A single macro indicator: shaped progress ring + current/goal values inside.
private struct MacroRing: View {
    let title: String
    let current: Double
    let goal: Double?
    let color: Color
    let shape: MacroShapeKind

    private var progress: CGFloat {
        guard let g = goal, g > 0 else { return 0 }
        return min(CGFloat(current / g), 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Label above ring
            Text(title)
                .dsTypography(.subheadline)
                .foregroundColor(DSColors.textSecondary)

            // Ring
            ZStack {
                // Track + Progress per shape
                switch shape {
                case .wavyCircle:
                    WavyCircleShape()
                        .stroke(color.opacity(0.15), lineWidth: 6)
                    WavyCircleShape()
                        .trim(from: 0, to: progress)
                        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        

                case .octagon:
                    PolygonShape(sides: 8)
                        .stroke(color.opacity(0.15), lineWidth: 6)
                    PolygonShape(sides: 8)
                        .trim(from: 0, to: progress)
                        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        

                case .roundedRect:
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(color.opacity(0.15), lineWidth: 6)
                    RoundedRectangle(cornerRadius: 24)
                        .trim(from: 0, to: progress)
                        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        
                }

                // Values inside
                VStack(spacing: 1) {
                    Text("\(Int(current))")
                        .font(.custom("InstrumentSans-SemiBold", size: 20))
                        .foregroundColor(color)

                    if let g = goal {
                        Text("\(Int(g))")
                            .font(.custom("InstrumentSans-Regular", size: 14))
                            .foregroundColor(color.opacity(0.5))
                    }
                }
            }
            .frame(width: 80, height: 80)
        }
    }
}

// MARK: - Calorie progress bar

/// Horizontal progress bar for calories: current / goal.
struct CalorieProgressBar: View {
    let current: Int
    let goal: Int?

    private var progress: CGFloat {
        guard let g = goal, g > 0 else { return 0 }
        return min(CGFloat(current) / CGFloat(g), 1.0)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(DSColors.primary.opacity(0.12))
                    .frame(height: 6)

                // Fill (with 1pt padding on each side)
                if let _ = goal {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(DSColors.primary)
                        .frame(width: max(0, (geo.size.width - 2) * progress), height: 2)
                        .offset(x: 2)
                }
            }
        }
        .frame(height: 6)
    }
}

// MARK: - NutritionPopupView

/// Bottom popup showing aggregated nutrition breakdown for the current entry.
/// Follows the same pattern as StreakPopupView — swipe/tap-outside to close.
struct NutritionPopupView: View {
    let nutrition: NutritionData
    let totalCalories: Int?
    let calorieGoal: Int?
    let proteinGoal: Double?
    let fatGoal: Double?
    let carbGoal: Double?
    let onClose: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false

    private let dragThreshold: CGFloat = 100

    /// The calorie value to display — prefer totalCalories (includes remote),
    /// fall back to nutrition.calories from local blocks.
    private var displayCalories: Int {
        totalCalories ?? nutrition.calories ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 24)
                .fill(DSColors.textSecondary.opacity(0.2))
                .frame(width: 48, height: 3)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Content
            VStack(spacing: 20) {
                // --- Calories section ---
                caloriesSection

                // --- Macros row (Carbs / Protein / Fat) ---
                macrosRow

                // --- Secondary nutrients ---
                secondaryNutrients
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(DSColors.surface)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 0)
        )
        .offset(y: max(0, dragOffset))
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    isDragging = false
                    let velocity = value.predictedEndLocation.y - value.location.y

                    if dragOffset > dragThreshold || velocity > 300 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = UIScreen.main.bounds.height
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onClose()
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .animation(isDragging ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
    }

    // MARK: - Calories section

    private var caloriesSection: some View {
        VStack(spacing: 2) {
            // "Calories" label
            HStack {
                Text("Calories")
                    .dsTypography(.subheadline)
                    .foregroundColor(DSColors.textSecondary)
                Spacer()
            }

            // Big current number (left) + smaller goal (right)
            HStack(alignment: .firstTextBaseline) {
                Text("\(displayCalories)")
                    .font(.dsLargeNumber)
                    .foregroundColor(DSColors.primary)

                Spacer()

                if let goal = calorieGoal {
                    Text("\(goal)")
                        .font(.custom("InstrumentSansCondensed-Medium", size: 32))
                        .foregroundColor(DSColors.primary.opacity(0.35))
                }
            }

            // Progress bar
            CalorieProgressBar(current: displayCalories, goal: calorieGoal)
        }
    }

    // MARK: - Macro circles row

    private var macrosRow: some View {
        let hasAnyMacro = (nutrition.carbs ?? 0) > 0
            || (nutrition.protein ?? 0) > 0
            || (nutrition.fat ?? 0) > 0

        return Group {
            if hasAnyMacro {
                HStack(spacing: 0) {
                    MacroRing(
                        title: "Carbs",
                        current: nutrition.carbs ?? 0,
                        goal: carbGoal,
                        color: MacroColor.carbs,
                        shape: .wavyCircle
                    )
                    Spacer()
                    MacroRing(
                        title: "Proteins",
                        current: nutrition.protein ?? 0,
                        goal: proteinGoal,
                        color: MacroColor.protein,
                        shape: .octagon
                    )
                    Spacer()
                    MacroRing(
                        title: "Fats",
                        current: nutrition.fat ?? 0,
                        goal: fatGoal,
                        color: MacroColor.fat,
                        shape: .roundedRect
                    )
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Secondary nutrients (fiber, sugar, sodium)

    private var secondaryNutrients: some View {
        let items: [(String, String)] = {
            var result: [(String, String)] = []
            if let fi = nutrition.fiber, fi > 0 { result.append(("Fiber", formatGrams(fi))) }
            if let s = nutrition.sugar, s > 0 { result.append(("Sugar", formatGrams(s))) }
            if let so = nutrition.sodium, so > 0 { result.append(("Sodium", formatGrams(so))) }
            return result
        }()

        return Group {
            if !items.isEmpty {
                Divider()

                VStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text(item.0)
                                .dsTypography(.subheadline)
                                .foregroundColor(DSColors.textSecondary)
                            Spacer()
                            Text(item.1)
                                .font(.dsHeadline)
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func formatGrams(_ value: Double) -> String {
        if value == value.rounded() {
            return "\(Int(value))g"
        }
        return String(format: "%.1fg", value)
    }
}

// MARK: - Container

/// Manages presentation with dimmed background, matching StreakPopupContainer.
struct NutritionPopupContainer: View {
    let nutrition: NutritionData
    let totalCalories: Int?
    let calorieGoal: Int?
    let proteinGoal: Double?
    let fatGoal: Double?
    let carbGoal: Double?
    let isPresented: Bool
    let onClose: () -> Void

    @State private var backgroundOpacity: Double = 0
    @State private var popupOffset: CGFloat = 0

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .bottom) {
                // Gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: 0x3F68E5).opacity(1),
                        Color(hex: 0x3F68E5).opacity(0)
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                .ignoresSafeArea()
                .onTapGesture {
                    closePopup()
                }

                // Popup content
                NutritionPopupView(
                    nutrition: nutrition,
                    totalCalories: totalCalories,
                    calorieGoal: calorieGoal,
                    proteinGoal: proteinGoal,
                    fatGoal: fatGoal,
                    carbGoal: carbGoal,
                    onClose: onClose
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .offset(y: popupOffset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .onChange(of: isPresented) { newValue in
                if newValue {
                    presentPopup()
                } else {
                    dismissPopup()
                }
            }
            .onAppear {
                if isPresented {
                    presentPopup()
                }
            }
        }
    }

    private func presentPopup() {
        popupOffset = UIScreen.main.bounds.height
        backgroundOpacity = 0

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            popupOffset = 0
            backgroundOpacity = 0.5
        }
    }

    private func dismissPopup() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            popupOffset = UIScreen.main.bounds.height
            backgroundOpacity = 0
        }
    }

    private func closePopup() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            popupOffset = UIScreen.main.bounds.height
            backgroundOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onClose()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NutritionPopupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ZStack {
                DSColors.background.ignoresSafeArea()

                NutritionPopupContainer(
                    nutrition: NutritionData(
                        calories: 2600,
                        protein: 24,
                        fat: 24,
                        carbs: 24,
                        fiber: 12,
                        sugar: 28,
                        sodium: 1.8,
                        weight: nil,
                        metric_description: nil,
                        confidence: nil,
                        userModified: nil
                    ),
                    totalCalories: 2600,
                    calorieGoal: 2970,
                    proteinGoal: 32,
                    fatGoal: 32,
                    carbGoal: 32,
                    isPresented: true,
                    onClose: {}
                )
            }
            .previewDisplayName("With Goals")

            ZStack {
                DSColors.background.ignoresSafeArea()

                NutritionPopupContainer(
                    nutrition: NutritionData(
                        calories: 1290,
                        protein: 85,
                        fat: 42,
                        carbs: 156,
                        fiber: 12,
                        sugar: 28,
                        sodium: 1.8,
                        weight: nil,
                        metric_description: nil,
                        confidence: nil,
                        userModified: nil
                    ),
                    totalCalories: 1290,
                    calorieGoal: nil,
                    proteinGoal: nil,
                    fatGoal: nil,
                    carbGoal: nil,
                    isPresented: true,
                    onClose: {}
                )
            }
            .previewDisplayName("No Goals")

            ZStack {
                DSColors.background.ignoresSafeArea()

                NutritionPopupContainer(
                    nutrition: NutritionData(
                        calories: 450,
                        protein: nil,
                        fat: nil,
                        carbs: nil,
                        fiber: nil,
                        sugar: nil,
                        sodium: nil,
                        weight: nil,
                        metric_description: nil,
                        confidence: nil,
                        userModified: nil
                    ),
                    totalCalories: 450,
                    calorieGoal: 2200,
                    proteinGoal: nil,
                    fatGoal: nil,
                    carbGoal: nil,
                    isPresented: true,
                    onClose: {}
                )
            }
            .previewDisplayName("Calories Only")
        }
    }
}
#endif
