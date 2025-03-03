import SwiftUI

struct LayoutConstants {
    // Screen partitioning
    static let calorieSlotWidth: CGFloat = 80
    static let textEditorPadding = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
    
    // Slot positioning
    static let slotSpacing: CGFloat = 0
    static let calorieTextPadding: EdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16)
    
    // Calculate the correct insets for the text view
    // The key insight: we need to add calorieSlotWidth to the trailing inset
    // so the text area properly reserves space for the calorie display
    static var textContainerInsets: UIEdgeInsets {
        UIEdgeInsets(
            top: textEditorPadding.top, 
            left: textEditorPadding.leading,
            bottom: textEditorPadding.bottom,
            right: textEditorPadding.trailing + calorieSlotWidth
        )
    }
    
    // Calculate available width for text from total width
    static func textWidth(fromTotalWidth totalWidth: CGFloat) -> CGFloat {
        return totalWidth - calorieSlotWidth - textEditorPadding.leading - textEditorPadding.trailing
    }
}
