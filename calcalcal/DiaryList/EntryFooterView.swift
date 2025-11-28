import SwiftUI
import UIKit

struct EntryFooterView: View {
    let blocks: [Block]
    let remoteTotalCalories: Int?
    let onAddImage: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onAddImage) {
                Image(systemName: "plus.circle")
                    .font(.title2)
            }
            .accessibilityLabel("Add Image")
            Spacer()
            CalorieTotalView(blocks: blocks, remoteTotalCalories: remoteTotalCalories)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct CalorieTotalView: View {
    let blocks: [Block]
    let remoteTotalCalories: Int?
    
    var body: some View {
        let localTotal = blocks.resolvedCalorieTotal()
        let displayValue = localTotal ?? remoteTotalCalories
        let labelText = displayValue.map { "\($0) kcal" } ?? "… kcal"
        return Text(labelText)
            .font(.headline)
            .foregroundColor(.secondary)
            .accessibilityLabel(accessibilityLabel(for: displayValue, isLocal: localTotal != nil))
            .animation(.easeInOut(duration: 0.2), value: displayValue)
    }
    
    private func accessibilityLabel(for value: Int?, isLocal: Bool) -> String {
        guard let value = value else {
            return "Calorie total not available yet"
        }
        return isLocal ? "Estimated total calories \(value)" : "Total calories \(value)"
    }
}

struct EntryFooterView_Previews: PreviewProvider {
    static var sampleBlocks: [Block] {
        [
            Block(type: .text("Breakfast: oats"), calorieData: "320"),
            Block(type: .text("Lunch: salad"), calorieData: "410")
        ]
    }
    
    static var previews: some View {
        EntryFooterView(
            blocks: sampleBlocks,
            remoteTotalCalories: 760,
            onAddImage: {}
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}