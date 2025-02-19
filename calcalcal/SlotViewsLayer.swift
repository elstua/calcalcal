import SwiftUI

struct SlotViewsLayer: View {
    @ObservedObject var lineManager: TextLineManager
    let slotProviders: [SlotViewProvider]
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Render slots for each paragraph
            ForEach(lineManager.paragraphs) { paragraph in
                // Only render for non-empty paragraphs
                if !paragraph.isEmpty {
                    // Get the last line of the paragraph to position the calories
                    let lastLineIndex = paragraph.endLineIndex
                    if lastLineIndex < lineManager.lineData.count {
                        let lastLine = lineManager.lineData[lastLineIndex]
                        
                        HStack(spacing: LayoutConstants.slotSpacing) {
                            // This ensures slot views are positioned at the end of text
                            Spacer()
                            
                            // Render slot views
                            ForEach(0..<slotProviders.count, id: \.self) { index in
                                let provider = slotProviders[index]
                                provider.createView(for: paragraph)
                                    .frame(width: provider.requiredWidth)
                            }
                        }
                        .frame(width: lastLine.lineRect.width + LayoutConstants.calorieSlotWidth)
                        .position(
                            // Center of HStack should be at half of text width plus half of slot width
                            x: (lastLine.lineRect.width + LayoutConstants.calorieSlotWidth)/2,
                            y: lastLine.lineRect.minY + lastLine.lineRect.height/2
                        )
                    }
                }
            }
        }
    }
}
