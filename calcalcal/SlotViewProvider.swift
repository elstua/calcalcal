import SwiftUI

protocol SlotViewProvider {
    var slotId: String { get }
    var requiredWidth: CGFloat { get }
    func createView(for lineData: LineData) -> AnyView
}

struct CalorieSlotProvider: SlotViewProvider {
    let slotId = "calories"
    let requiredWidth: CGFloat = 100
    private let calorieCalculator: (String) -> Int?
    
    init(calorieCalculator: @escaping (String) -> Int? = { _ in Int.random(in: 100...500) }) {
        self.calorieCalculator = calorieCalculator
    }
    
    func createView(for lineData: LineData) -> AnyView {
        // Get calories from metadata or calculate
        let calories = lineData.metadata["calories"] as? Int ??
                     (lineData.text.isEmpty ? nil : calorieCalculator(lineData.text))
        
        guard let calories = calories else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            Text("\(calories) kcal")
                .foregroundColor(.secondary)
                .font(.system(size: 18))
                .frame(width: requiredWidth, alignment: .trailing)
        )
    }
}
