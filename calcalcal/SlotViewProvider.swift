import SwiftUI

protocol SlotViewProvider {
    var slotId: String { get }
    var requiredWidth: CGFloat { get }
    func createView(for paragraph: TextLineManager.ParagraphData) -> AnyView
}

struct CalorieSlotProvider: SlotViewProvider {
    let slotId = "calories"
    // Use centralized constant
    var requiredWidth: CGFloat { LayoutConstants.calorieSlotWidth }
    
    func createView(for paragraph: TextLineManager.ParagraphData) -> AnyView {
        // Get calories from metadata or return empty view for empty paragraphs
        guard !paragraph.isEmpty else {
            return AnyView(EmptyView())
        }
        
        let calories = paragraph.metadata["calories"] as? Int ?? 0
        
        return AnyView(
            Text("\(calories) kcal")
                .foregroundColor(.secondary)
                .font(.system(size: 18))
                .frame(width: requiredWidth, alignment: .trailing)
                .padding(LayoutConstants.calorieTextPadding)
        )
    }
}
