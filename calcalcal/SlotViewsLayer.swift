import SwiftUI

struct SlotViewsLayer: View {
    @ObservedObject var lineManager: TextLineManager
    let slotProviders: [any SlotViewProvider]
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(lineManager.lineData) { line in
                HStack(spacing: 0) {
                    Spacer(minLength: line.lineRect.width)
                    
                    // Use index-based ForEach instead
                    ForEach(0..<slotProviders.count, id: \.self) { index in
                        let provider = slotProviders[index]
                        provider.createView(for: line)
                            .frame(width: provider.requiredWidth)
                    }
                }
                .position(
                    x: line.lineRect.width/2,
                    y: line.lineRect.minY + line.lineRect.height/2
                )
            }
        }
    }
}
