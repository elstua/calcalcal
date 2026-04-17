import SwiftUI

/// Sticky footer overlay for the editor, containing a gallery thumbnail button (left)
/// and an animated calorie number (right).
struct EditorFooterView: View {
    let blocks: [Block]
    let remoteTotalCalories: Int?
    let scrollOffset: CGFloat
    let calorieGoal: Int?
    let onAddImage: () -> Void
    let onCalorieTap: () -> Void

    private let scrollThreshold: CGFloat = 60

    private var shrinkProgress: CGFloat {
        min(1, max(0, scrollOffset / scrollThreshold))
    }

    private var calorieValue: Int? {
        blocks.resolvedCalorieTotal() ?? remoteTotalCalories
    }

    var body: some View {
        HStack(alignment: .center) {
            GalleryThumbnailButton(action: onAddImage)

            Spacer(minLength: 0)

            CalorieBarrelView(
                value: calorieValue,
                font: .dsLargeNumber,
                color: DSColors.primary
            )
            .overlay(alignment: .bottomTrailing) {
                if calorieGoal != nil {
                    AngledCalorieBar(
                        current: calorieValue ?? 0,
                        goal: calorieGoal,
                        shrinkProgress: shrinkProgress
                    )
                    .frame(width: 120)
                    .offset(y: 8)
                    .offset(x: 14)
                }
            }
            .onTapGesture { onCalorieTap() }
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.sm)
    }
}

// MARK: - Angled Calorie Progress Bar

/// An L-shaped progress line that runs horizontally under the calorie number
/// and curves up along the right edge. On scroll the vertical arm collapses
/// and the line straightens out, matching the calorie number's shrink animation.
private struct AngledCalorieBar: View {
    let current: Int
    let goal: Int?
    let shrinkProgress: CGFloat

    @State private var animatedProgress: CGFloat = 0

    private let maxVerticalRise: CGFloat = 56
    private let maxCornerRadius: CGFloat = 22

    private var verticalRise: CGFloat {
        maxVerticalRise * (1 - shrinkProgress)
    }
    private var cornerRadius: CGFloat {
        maxCornerRadius * (1 - shrinkProgress)
    }

    private var targetProgress: CGFloat {
        guard let g = goal, g > 0 else { return 0 }
        return min(CGFloat(current) / CGFloat(g), 1.0)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AngledBarShape(cornerRadius: cornerRadius, verticalRise: verticalRise)
                .stroke(DSColors.primary.opacity(0.12), style: StrokeStyle(lineWidth: 5, lineCap: .round))

            AngledBarShape(cornerRadius: cornerRadius, verticalRise: verticalRise)
                .trim(from: 0, to: animatedProgress)
                .stroke(DSColors.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .frame(height: max(verticalRise + 6, 8))
        .onAppear {
            animatedProgress = targetProgress
        }
        .onChange(of: current) { _, _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animatedProgress = targetProgress
            }
        }
        .onChange(of: goal) { _, _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animatedProgress = targetProgress
            }
        }
    }
}

/// Shape: horizontal line from left to right, then curves upward at the right edge.
/// Conforms to Animatable so verticalRise and cornerRadius interpolate smoothly.
private struct AngledBarShape: Shape {
    var cornerRadius: CGFloat
    var verticalRise: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(cornerRadius, verticalRise) }
        set {
            cornerRadius = newValue.first
            verticalRise = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let bottom = rect.maxY - 2          // bottom line y
        let right = rect.maxX - 2           // right edge x

        // When verticalRise is ~0, just draw a straight horizontal line
        if verticalRise < 1 {
            path.move(to: CGPoint(x: rect.minX, y: bottom))
            path.addLine(to: CGPoint(x: right, y: bottom))
            return path
        }

        let top = bottom - verticalRise     // top of vertical segment
        let clampedRadius = min(cornerRadius, verticalRise) // don't overshoot
        let curveStartY = bottom - clampedRadius
        let curveEndX = right - clampedRadius

        // Start from the left at the bottom
        path.move(to: CGPoint(x: rect.minX, y: bottom))
        // Horizontal segment to the start of the curve
        path.addLine(to: CGPoint(x: curveEndX, y: bottom))
        // Rounded corner going up
        path.addQuadCurve(
            to: CGPoint(x: right, y: curveStartY),
            control: CGPoint(x: right, y: bottom)
        )
        // Vertical segment going up
        path.addLine(to: CGPoint(x: right, y: top))

        return path
    }
}

#if DEBUG
struct EditorFooterView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            EditorFooterView(
                blocks: [
                    Block(type: .text("Oatmeal with banana"), calorieData: "320", nutrition: nil),
                    Block(type: .text("Chicken salad"), calorieData: "450", nutrition: nil),
                ],
                remoteTotalCalories: 770,
                scrollOffset: 0,
                calorieGoal: 2200,
                onAddImage: {},
                onCalorieTap: {}
            )
            .background(DSColors.surfaceSecondary)
        }
    }
}
#endif
