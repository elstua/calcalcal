import SwiftUI
import UIKit


struct TextViewRepresentable: UIViewRepresentable {
    @Binding var text: String
    var lineManager: TextLineManager
    var onFocusChange: (Bool) -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 18)
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = LayoutConstants.textContainerInsets
        
        // Set placeholder if text is empty
        if text.isEmpty {
            textView.text = "Start to write what you eat..."
            textView.textColor = UIColor.placeholderText
        } else {
            textView.text = text
            textView.textColor = UIColor.label
        }
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        // Don't update if handling placeholder
        if !context.coordinator.isHandlingPlaceholder {
            if textView.text != text {
                textView.text = text
                lineManager.updateLineData(from: textView)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, lineManager: lineManager, onFocusChange: onFocusChange)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        let lineManager: TextLineManager
        let onFocusChange: (Bool) -> Void
        var isHandlingPlaceholder = false
        
        init(text: Binding<String>, lineManager: TextLineManager, onFocusChange: @escaping (Bool) -> Void) {
            self._text = text
            self.lineManager = lineManager
            self.onFocusChange = onFocusChange
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            onFocusChange(true)
            
            // Clear placeholder when editing begins
            if textView.textColor == UIColor.placeholderText {
                isHandlingPlaceholder = true
                textView.text = ""
                textView.textColor = UIColor.label
                isHandlingPlaceholder = false
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            onFocusChange(false)
            
            // Show placeholder if text is empty
            if textView.text.isEmpty {
                isHandlingPlaceholder = true
                textView.text = "Start to write what you eat..."
                textView.textColor = UIColor.placeholderText
                isHandlingPlaceholder = false
            }
            
            lineManager.updateLineData(from: textView)
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // Only update binding if not placeholder
            if textView.textColor != UIColor.placeholderText {
                text = textView.text
            }
            
            lineManager.updateLineData(from: textView)
        }
    }
}
