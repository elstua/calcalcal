import SwiftUI
import UIKit

/// SwiftUI wrapper for the unified text editor
struct UnifiedTextEditor: UIViewRepresentable {
    
    @Binding var text: String
    var onTextChange: ((String) -> Void)?
    var defaultBlockSpacing: CGFloat = 16.0
    
    func makeUIView(context: Context) -> UnifiedTextView {
        let textView = UnifiedTextView()
        textView.defaultBlockSpacing = defaultBlockSpacing
        textView.text = text
        
        // Set up the coordinator as delegate
        textView.delegate = context.coordinator
        
        return textView
    }
    
    func updateUIView(_ textView: UnifiedTextView, context: Context) {
        // Update text if it changed externally
        if textView.text != text {
            textView.text = text
        }
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
} 