import SwiftUI
import UIKit

struct BlockEditorTestView: View {
    @State private var blocks: [Block] = [
        Block(type: .text("Bulletproof coffee"), calorieData: "120"),
        Block(type: .text("Overnight oats with chia and banana"), calorieData: "340"),
        Block(type: .text("Grilled salmon with quinoa bowl"), calorieData: "560"),
        Block(type: .text("Dark chocolate square"), calorieData: "80")
    ]
    @State private var imageMap: [UUID: UIImage] = [:]
    @State private var shouldBecomeFirstResponder = false
    @State private var editorTextView: BlockEditorTextView?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                BlockEditorRepresentable(
                    blocks: $blocks,
                    imageMap: imageMap,
                    shouldBecomeFirstResponder: $shouldBecomeFirstResponder,
                    onBlocksChange: { updated in
                        blocks = updated
                    },
                    onTextViewReady: { textView in
                        editorTextView = textView
                        DispatchQueue.main.async {
                            self.applySampleCalorieLabels()
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color(uiColor: .separator), lineWidth: 1)
                )
                
                Button("Insert sample image block") {
                    if let image = UIImage(systemName: "photo") {
                        editorTextView?.insertImageBlock(image: image)
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Text("Blocks: \(blocks.count)")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ScrollView {
                    Text(blocks.map { blockText(for: $0) }
                        .joined(separator: "\n"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .frame(maxHeight: 160)
            }
            .padding(20)
            .navigationTitle("Editor V2 Test")
        }
    }
    
    private func applySampleCalorieLabels() {
        guard let textView = editorTextView else { return }
        let blocks = textView.blockDocumentController.document.blocks
        guard !blocks.isEmpty else {
            textView.setCalorieLabels([:])
            return
        }
        
        var labels: [BlockID: String] = [:]
        for (index, block) in blocks.enumerated() {
            let calories = 120 + (index * 70)
            labels[block.id] = "\(calories) kcal"
        }
        textView.setCalorieLabels(labels)
    }
    
    private func blockText(for block: Block) -> String {
        switch block.type {
        case .text(let text):
            return text
        case .imageText(_, _, let text):
            return text
        case .image:
            return "[image]"
        case .spacer:
            return ""
        }
    }
}

struct BlockEditorTestView_Previews: PreviewProvider {
    static var previews: some View {
        BlockEditorTestView()
    }
}



