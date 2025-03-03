import SwiftUI

protocol SlotViewProvider {
    var slotId: String { get }
    var requiredWidth: CGFloat { get }
    func createView(for paragraph: TextLineManager.ParagraphData, isFocused: Bool, fullText: String) -> AnyView
}

struct CalorieSlotProvider: SlotViewProvider {
    let slotId = "calories"
    var requiredWidth: CGFloat { LayoutConstants.calorieSlotWidth }
    
    // Add a callback for the add button
    var onAddButtonTapped: (() -> Void)?
    
    func createView(for paragraph: TextLineManager.ParagraphData, isFocused: Bool = true, fullText: String = "") -> AnyView {
        // For empty paragraphs or when the entire text is empty, show the add button
        if paragraph.isEmpty || fullText.isEmpty {
            return AnyView(
                HStack {
                    Spacer()
                    AddButton(action: {
                        onAddButtonTapped?()
                    })
                }
                .frame(width: requiredWidth)
            )
        }
        
        // For non-empty paragraphs, show calories
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

// Provider for placeholder text (unchanged)
struct PlaceholderSlotProvider: SlotViewProvider {
    let slotId = "placeholder"
    var requiredWidth: CGFloat {
        // Use a large value that will take up most of the available space
        return 300
    }
    
    func createView(for paragraph: TextLineManager.ParagraphData, isFocused: Bool = true, fullText: String = "") -> AnyView {
        // Only show placeholder on empty paragraphs
        guard paragraph.isEmpty else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            HStack {
                Text("Start to write what you eat...")
                    .foregroundColor(.gray)
                    .font(.system(size: 18))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .padding(.trailing, 50) // Add some padding for the button
        )
    }
}
