import SwiftUI

/// Sticky footer overlay for the editor, containing a gallery thumbnail button (left)
/// and an animated calorie number (right) that shrinks on scroll.
struct EditorFooterView: View {
    let blocks: [Block]
    let remoteTotalCalories: Int?
    let scrollOffset: CGFloat
    let onAddImage: () -> Void

    /// Scroll distance over which the number transitions from large to compact
    private let scrollThreshold: CGFloat = 60
    /// Minimum scale factor (dsCompactNumber 17pt / dsLargeNumber 48pt)
    private let minScale: CGFloat = 17.0 / 48.0

    private var shrinkProgress: CGFloat {
        min(1, max(0, scrollOffset / scrollThreshold))
    }

    private var numberScale: CGFloat {
        1.0 - (1.0 - minScale) * shrinkProgress
    }

    private var calorieValue: Int? {
        blocks.resolvedCalorieTotal() ?? remoteTotalCalories
    }

    var body: some View {
        HStack(alignment: .bottom) {
            GalleryThumbnailButton(action: onAddImage)

            Spacer(minLength: 0)

            CalorieBarrelView(
                value: calorieValue,
                font: .dsLargeNumber,
                color: DSColors.primary
            )
            .scaleEffect(numberScale, anchor: .trailing)
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.sm)
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
                onAddImage: {}
            )
            .background(Color.gray.opacity(0.1))
        }
    }
}
#endif
