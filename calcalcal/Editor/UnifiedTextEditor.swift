import SwiftUI
import UIKit

/// SwiftUI wrapper for the unified text editor
struct UnifiedTextEditor: UIViewRepresentable {
    
    @Binding var blocks: [Block]
    var imageMap: [UUID: UIImage] = [:]
    var onBlocksChange: (([Block]) -> Void)?
    var defaultBlockSpacing: CGFloat = 32
    
    func makeUIView(context: Context) -> UnifiedTextView {
        let textView = UnifiedTextView()
        textView.defaultBlockSpacing = defaultBlockSpacing
        textView.blocks = blocks
        textView.imageMap = imageMap
        textView.delegate = context.coordinator
        print("[makeUIView] Initial blocks: \(blocks)")
        textView.renderBlocks()
        print("[makeUIView] Called renderBlocks()")
        return textView
    }
    
    func updateUIView(_ textView: UnifiedTextView, context: Context) {
        // Only update if the change is external
        if textView.blocks != blocks {
            print("[updateUIView] Updating blocks: \(blocks)")
            textView.blocks = blocks
            textView.renderBlocks()
            print("[updateUIView] Called renderBlocks()")
        }
        textView.imageMap = imageMap
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// Syncs the blocks array from the UITextView's content and metadata
    func updateBlocksFromTextStorage(_ textView: UnifiedTextView) {
        // This is a placeholder implementation. You should parse the textView's content and metadata to reconstruct blocks.
        // For now, we just assign textView.blocks to the binding.
        let newBlocks = textView.blocks
        if newBlocks != blocks {
            DispatchQueue.main.async {
                self.blocks = newBlocks
                self.onBlocksChange?(newBlocks)
            }
        }
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: UnifiedTextEditor
        
        init(_ parent: UnifiedTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            guard let unifiedTextView = textView as? UnifiedTextView else { return }
            unifiedTextView.textViewDidChange(textView)
            parent.updateBlocksFromTextStorage(unifiedTextView)
        }
    }
}

// MARK: - View Modifiers

extension UnifiedTextEditor {
    
    func blockSpacing(_ spacing: CGFloat) -> UnifiedTextEditor {
        var editor = self
        editor.defaultBlockSpacing = spacing
        return editor
    }
    
    func onBlocksChange(_ action: @escaping ([Block]) -> Void) -> UnifiedTextEditor {
        var editor = self
        editor.onBlocksChange = action
        return editor
    }
} 