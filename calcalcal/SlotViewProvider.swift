import SwiftUI

protocol SlotViewProvider {
    var slotId: String { get }
    var requiredWidth: CGFloat { get }
    func createView(for paragraph: TextLineManager.ParagraphData) -> AnyView
}

struct CalorieSlotProvider: SlotViewProvider {
    let slotId = "calories"
    let requiredWidth: CGFloat = 100 // Reduced width to fix padding issue
    
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
//                .frame(width: requiredWidth, alignment: .trailing)
                .padding(.trailing, 24) // Small padding
        )
    }
}
