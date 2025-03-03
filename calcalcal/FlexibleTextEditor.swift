import SwiftUI
import UIKit

struct FlexibleTextEditor: View {
    @StateObject private var lineManager = TextLineManager()
    @Binding var text: String
    @Binding var isFocused: Bool
    var slotProviders: [SlotViewProvider]
    var onCaloriesCalculated: (Int) -> Void
    
    // Add a callback for the add button
    var onAddButtonTapped: (() -> Void)? = nil
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Main text editor
                TextViewRepresentable(
                    text: $text,
                    lineManager: lineManager,
                    onFocusChange: { focused in
                        isFocused = focused
                    },
                    // Use the built-in placeholder
                    showPlaceholder: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    lineManager.onDataUpdated = { paragraphs in
                        calculateCalories(for: paragraphs)
                    }
                }
                
                // Handle empty text field case separately with fixed positioning
                if text.isEmpty && lineManager.lineData.count > 0 {
                    HStack {
                        Spacer()
                        AddButton(action: {
                            onAddButtonTapped?() ?? print("Add button tapped")
                        })
                    }
                    .padding(.trailing, 12)
                    .frame(width: geometry.size.width)
                    .offset(y: 4) // Fixed position near the top
                }
                else {
                    // Show calorie slots for non-empty paragraphs
                    ForEach(lineManager.paragraphs.indices, id: \.self) { index in
                        let paragraph = lineManager.paragraphs[index]
                        
                        if !paragraph.isEmpty && index < lineManager.lineData.count {
                            let line = lineManager.lineData[paragraph.endLineIndex]
                            
                            // Show calorie information
                            HStack {
                                Spacer()
                                
                                if let calories = paragraph.metadata["calories"] as? Int {
                                    Text("\(calories) kcal")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 18))
                                        .frame(width: LayoutConstants.calorieSlotWidth, alignment: .trailing)
                                        .padding(LayoutConstants.calorieTextPadding)
                                }
                            }
                            .frame(width: geometry.size.width)
                            .offset(x: 0, y: line.lineRect.minY)
                        }
                    }
                }
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
