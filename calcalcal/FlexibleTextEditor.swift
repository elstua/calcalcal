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
                        lineManager.onDataUpdated = { paragraphs in
                            calculateCalories(for: paragraphs)
                        }
                        
                        // No need to call updateAvailableWidth if you're not storing width
                        // Just let the TextViewRepresentable handle the insets
                    }
                
                // Layer for slot views
                SlotViewsLayer(
                    lineManager: lineManager,
                    slotProviders: slotProviders
                )
            }
        }
    }
    
    private func calculateCalories(for paragraphs: [TextLineManager.ParagraphData]) {
        var totalCalories = 0
        
        // Process each paragraph - only calculate for non-empty ones
        for (index, paragraph) in paragraphs.enumerated() {
            if !paragraph.isEmpty {
                // Calculate calories based on paragraph text length
                // This is where you would call your LLM in the future
                let calories = randomCaloriesForText(paragraph.text)
                lineManager.addParagraphMetadata(for: index, key: "calories", value: calories)
                totalCalories += calories
            }
        }
        
        onCaloriesCalculated(totalCalories)
    }
    
    // Generate reasonable calories based on text length
    private func randomCaloriesForText(_ text: String) -> Int {
        // Base calories on text length for more realistic values
        let baseCalories = max(100, min(text.count * 5, 1500))
        // Add some randomness but keep it within reasonable range
        return baseCalories + Int.random(in: -50...50)
    }
}
