import SwiftUI

struct SlotViewsLayer: View {
    @ObservedObject var lineManager: TextLineManager
    let slotProviders: [SlotViewProvider]
    let isFocused: Bool
    let text: String
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Render slots for each paragraph
            ForEach(lineManager.paragraphs) { paragraph in
                // Only render for non-empty paragraphs
                if !paragraph.isEmpty {
                    // Get the last line of the paragraph for positioning
                    let lastLineIndex = paragraph.endLineIndex
                    if lastLineIndex < lineManager.lineData.count {
                        let lastLine = lineManager.lineData[lastLineIndex]
                        
                        HStack(spacing: LayoutConstants.slotSpacing) {
                            Spacer()
                            
                            // Pass state to slot providers
                            ForEach(0..<slotProviders.count, id: \.self) { index in
                                let provider = slotProviders[index]
                                provider.createView(
                                    for: paragraph,
                                    isFocused: isFocused,
                                    fullText: text
                                )
                                .frame(width: provider.requiredWidth)
                            }
                        }
                        .frame(width: lastLine.lineRect.width + LayoutConstants.calorieSlotWidth)
                        .position(
                            x: (lastLine.lineRect.width + LayoutConstants.calorieSlotWidth)/2,
                            y: lastLine.lineRect.minY + lastLine.lineRect.height/2
                        )
                    }
                }
            }
            
            // Show button in center if text is empty and not focused
            if text.isEmpty {
                HStack {
                    Spacer()
                    AddButton(action: { /* Future functionality */ })
                }
                .padding(.trailing, 10)
            }
        }
    }
}
