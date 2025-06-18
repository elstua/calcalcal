import SwiftUI
import UIKit

/// Proxy class to expose UnifiedTextView methods to SwiftUI
class UnifiedTextEditorProxy: ObservableObject {
    weak var textView: UnifiedTextView?
    
    func addTextBlock(_ text: String, calorieData: String? = nil) {
        textView?.addTextBlock(text, calorieData: calorieData)
    }
    
    func addImageBlock(_ text: String = "This is an image block with text flowing alongside. The image takes up 30% of the width while the text uses the remaining 70%.", imageReference: UUID? = nil, calorieData: String? = nil) {
        textView?.addImageBlock(text, imageReference: imageReference, calorieData: calorieData)
    }
}

/// SwiftUI wrapper for the unified text editor
struct UnifiedTextEditor: UIViewRepresentable {
    
    @Binding var text: String
    var imageMap: [UUID: UIImage] = [:]
    var onTextChange: ((String) -> Void)?
    var defaultBlockSpacing: CGFloat = 32
    var proxy: UnifiedTextEditorProxy?
    
    func makeUIView(context: Context) -> UnifiedTextView {
        let textView = UnifiedTextView()
        textView.defaultBlockSpacing = defaultBlockSpacing
        textView.text = text
        textView.imageMap = imageMap
        proxy?.textView = textView
        return textView
    }
    
    func updateUIView(_ textView: UnifiedTextView, context: Context) {
        // Update text if it changed externally
        if textView.text != text {
            textView.text = text
            
            // If text was cleared externally, force cleanup of all visual elements
            if text.isEmpty {
                // Force update to clean up image views and metadata
                DispatchQueue.main.async {
                    textView.setNeedsLayout()
                    textView.layoutIfNeeded()
                }
            }
        }
        textView.imageMap = imageMap
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: UnifiedTextEditor
        
        init(_ parent: UnifiedTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.onTextChange?(textView.text)
            
            // The UnifiedTextView already handles block updates internally
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
    
    func onTextChange(_ action: @escaping (String) -> Void) -> UnifiedTextEditor {
        var editor = self
        editor.onTextChange = action
        return editor
    }
    
    func proxy(_ proxy: UnifiedTextEditorProxy) -> UnifiedTextEditor {
        var editor = self
        editor.proxy = proxy
        return editor
    }
} 