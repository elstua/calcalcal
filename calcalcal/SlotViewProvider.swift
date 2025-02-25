import SwiftUI

protocol SlotViewProvider {
    var slotId: String { get }
    var requiredWidth: CGFloat { get }
    func createView(for paragraph: TextLineManager.ParagraphData, isFocused: Bool, fullText: String) -> AnyView
}

struct CalorieSlotProvider: SlotViewProvider {
    let slotId = "calories"
    var requiredWidth: CGFloat { LayoutConstants.calorieSlotWidth }
    
    func createView(for paragraph: TextLineManager.ParagraphData, isFocused: Bool = true, fullText: String = "") -> AnyView {
        // If text is empty and not focused, show the + button
        if !isFocused && fullText.isEmpty {
            return AnyView(
                AddButton(action: {
                    // This will be used for image selection in the future
                    print("Add button tapped")
                })
                .frame(width: requiredWidth, alignment: .trailing)
                .padding(LayoutConstants.calorieTextPadding)
            )
        }
        
        // Otherwise show calories for non-empty paragraphs
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
