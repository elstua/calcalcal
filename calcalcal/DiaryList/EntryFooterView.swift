import SwiftUI
import UIKit

struct EntryFooterView: View {
    let blocks: [Block]
    let remoteTotalCalories: Int?
    let onAddImage: () -> Void
    
    // Access app state to get user goals
    @EnvironmentObject var appState: AppState
    @State private var showDayOverview: Bool = false
    
    var body: some View {
        HStack {
            Button(action: onAddImage) {
                Image(systemName: "plus.circle")
                    .font(.title2)
            }
            .accessibilityLabel("Add Image")
            Spacer()
            
            Button(action: {
                showDayOverview = true
            }) {
                CalorieTotalView(blocks: blocks, remoteTotalCalories: remoteTotalCalories)
            }
            .buttonStyle(PlainButtonStyle())
            // Present the overview as a popover
            .popover(isPresented: $showDayOverview) {
                DayOverviewContextMenuView(
                    consumed: blocks.resolvedNutritionTotal(),
                    user: appState.currentUser,
                    // Use a fixed width suitable for a readable card, or screen width minus padding
                    width: UIScreen.main.bounds.width - 48
                )
                .presentationCompactAdaptation(.popover) // Ensure it stays as popover on iPhone if possible (iOS 16.4+)
            }
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
        // Inject mock AppState for preview
        .environmentObject(AppState())
        .previewLayout(.sizeThatFits)
        .padding()
    }
}