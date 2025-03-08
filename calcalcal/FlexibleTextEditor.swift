import SwiftUI
import UIKit

struct FlexibleTextEditor: View {
    @StateObject private var lineManager = TextLineManager()
    @Binding var text: String
    @Binding var isFocused: Bool
    var slotProviders: [SlotViewProvider]
    var onCaloriesCalculated: (Int) -> Void
    
    // Track scroll position
    @State private var scrollOffset: CGFloat = 0
    
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
                    // Track scroll position
                    onScrollChange: { offset in
                        scrollOffset = offset
                    },
                    showPlaceholder: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    lineManager.onDataUpdated = { paragraphs in
                        calculateCalories(for: paragraphs)
                    }
                }
                
                // Add button for empty state with fixed position
                if text.isEmpty {
                    VStack {
                        HStack {
                            Spacer()
                            AddButton(action: {
                                print("Add button tapped for image selection")
                            })
                            .padding(.trailing, 20)
                        }
                        .padding(.top, 12)
                        Spacer()
                    }
                }
                
                // Show all calorie slots without conditional rendering
                // Just rely on clipping to prevent overlap
                ZStack {
                    ForEach(lineManager.paragraphs.indices, id: \.self) { index in
                        let paragraph = lineManager.paragraphs[index]
                        
                        if !paragraph.isEmpty && index < lineManager.lineData.count {
                            let line = lineManager.lineData[paragraph.endLineIndex]
                            
                            // Show calorie information adjusted by scroll offset
                            if let calories = paragraph.metadata["calories"] as? Int {
                                let yPosition = line.lineRect.minY + line.lineRect.height/2 - scrollOffset
                                
                                // Render all calories without visibility check
                                Text("\(calories) kcal")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 18))
                                    .frame(width: LayoutConstants.calorieSlotWidth, alignment: .trailing)
                                    .position(
                                        x: geometry.size.width - (LayoutConstants.calorieSlotWidth/2),
                                        y: yPosition
                                    )
                            }
                        }
                    }
                }
                // Apply clipping to the entire calorie display container
                .clipShape(Rectangle())
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
