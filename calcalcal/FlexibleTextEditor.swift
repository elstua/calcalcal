import SwiftUI

struct FlexibleTextEditor: View {
    @StateObject private var lineManager = TextLineManager()
    @Binding var text: String
    var slotProviders: [SlotViewProvider]
    var onCaloriesCalculated: (Int) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Main text editor
                TextViewRepresentable(text: $text, lineManager: lineManager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        // Set up callback for updates
                        lineManager.onDataUpdated = { newLines in
                            calculateCalories(for: newLines)
                        }
                    }
                
                // Layer for slot views
                SlotViewsLayer(
                    lineManager: lineManager,
                    slotProviders: slotProviders
                )
            }
        }
    }
    
    private func calculateCalories(for lines: [LineData]) {
        var totalCalories = 0
        
        // Process each line
        for (index, line) in lines.enumerated() {
            if !line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let calories = Int.random(in: 100...1000)
                lineManager.addMetadata(for: index, key: "calories", value: calories)
                totalCalories += calories
            }
        }
        
        onCaloriesCalculated(totalCalories)
    }
}
