import Foundation
import SwiftUI

// Keep for backwards compatibility
struct TextEntry: Identifiable {
    let id: UUID
    var text: String
    var calories: Int?
    var height: CGFloat = 0
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init(id: UUID = UUID(), text: String, calories: Int? = nil, height: CGFloat = 0) {
        self.id = id
        self.text = text
        self.calories = calories
        self.height = height
    }
}

class DocumentViewModel: ObservableObject {
    @Published var text: String = ""
    @Published private(set) var entries: [TextEntry] = []
    @Published private(set) var totalCalories: Int = 0
    
    func processTextChange(_ newText: String) {
        self.text = newText
    }
    
    func updateTotalCalories(_ total: Int) {
        self.totalCalories = total
    }
}
