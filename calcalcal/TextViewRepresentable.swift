import SwiftUI
import UIKit

struct TextViewRepresentable: UIViewRepresentable {
    @Binding var text: String
    var lineManager: TextLineManager
    var onFocusChange: (Bool) -> Void
    var onSelectionChange: ((UITextView) -> Void)? = nil // New callback for selection changes
    var showPlaceholder: Bool = true
    
    // Placeholder text
    private let placeholderText = "Start to write what you eat..."
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 18)
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = LayoutConstants.textContainerInsets
        
        // Set initial text
        textView.text = text
        textView.textColor = UIColor.label
        
        // Set placeholder if text is empty
        if text.isEmpty && showPlaceholder {
            textView.text = placeholderText
            textView.textColor = UIColor.placeholderText
        }
        
        // Initialize line data
        lineManager.updateLineData(from: textView)
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        // Don't update if handling placeholder
        if !context.coordinator.isHandlingPlaceholder {
            // Only update if the text has changed
            if textView.text != text && !(text.isEmpty && textView.text == placeholderText) {
                // If text is empty and placeholder should be shown
                if text.isEmpty && showPlaceholder {
                    if textView.text != placeholderText {
                        textView.text = placeholderText
                        textView.textColor = UIColor.placeholderText
                    }
                } else {
                    textView.text = text
                    textView.textColor = UIColor.label
                }
                
                // Update line data
                lineManager.updateLineData(from: textView)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            lineManager: lineManager,
            onFocusChange: onFocusChange,
            onSelectionChange: onSelectionChange,
            placeholderText: placeholderText
        )
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        let lineManager: TextLineManager
        let onFocusChange: (Bool) -> Void
        let onSelectionChange: ((UITextView) -> Void)?
        let placeholderText: String
        var isHandlingPlaceholder = false
        
        init(text: Binding<String>,
             lineManager: TextLineManager,
             onFocusChange: @escaping (Bool) -> Void,
             onSelectionChange: ((UITextView) -> Void)? = nil,
             placeholderText: String) {
            self._text = text
            self.lineManager = lineManager
            self.onFocusChange = onFocusChange
            self.onSelectionChange = onSelectionChange
            self.placeholderText = placeholderText
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
            
            // Notify about cursor position when editing begins
            onSelectionChange?(textView)
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            onFocusChange(false)
            
            // Show placeholder if text is empty
            if textView.text.isEmpty {
                isHandlingPlaceholder = true
                textView.text = placeholderText
                textView.textColor = UIColor.placeholderText
                isHandlingPlaceholder = false
            }
            
            lineManager.updateLineData(from: textView)
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // Only update binding if not placeholder
            if textView.textColor != UIColor.placeholderText {
                text = textView.text
            } else {
                // If it's a placeholder, set binding to empty
                text = ""
            }
            
            // Update line data
            lineManager.updateLineData(from: textView)
            
            // Track selection changes when text changes
            onSelectionChange?(textView)
        }
        
        // Track selection changes
        func textViewDidChangeSelection(_ textView: UITextView) {
            // If the text is the placeholder and the user tries to select it,
            // move the cursor to the beginning
            if textView.textColor == UIColor.placeholderText {
                textView.selectedRange = NSRange(location: 0, length: 0)
            }
            
            // Notify about selection change
            onSelectionChange?(textView)
        }
    }
}
