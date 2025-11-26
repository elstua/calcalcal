import SwiftUI
import UIKit

struct BlockEditorTestView: View {
    @State private var text: String = """
    Bulletproof coffee
    Overnight oats with chia and banana
    Grilled salmon with quinoa bowl
    Dark chocolate square
    """
    @State private var editorTextView: BlockEditorTextView?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                BlockEditorRepresentable(text: $text) { textView in
                    // Capture the underlying UITextView for debugging actions.
                    self.editorTextView = textView
                    DispatchQueue.main.async {
                        self.applySampleCalorieLabels()
                    }
                }
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
                
                Text("Current text:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ScrollView {
                    Text(text.isEmpty ? "Start typing above…" : text)
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
        .onAppear {
            DispatchQueue.main.async {
                self.applySampleCalorieLabels()
            }
        }
        .onChange(of: text) { _ in
            DispatchQueue.main.async {
                self.applySampleCalorieLabels()
            }
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
}


struct BlockEditorTestView_Previews: PreviewProvider {
    static var previews: some View {
        BlockEditorTestView()
    }
}



