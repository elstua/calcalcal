import SwiftUI
import UIKit

struct TextViewRepresentable: UIViewRepresentable {
    @Binding var text: String
    var lineManager: TextLineManager
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 18)
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.backgroundColor = .clear
        // Reduced right padding to 88 (80 for calories + 8 for spacing)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 8, right: 120)
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            textView.text = text
            lineManager.updateLineData(from: textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, lineManager: lineManager)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        let lineManager: TextLineManager
        
        init(text: Binding<String>, lineManager: TextLineManager) {
            self._text = text
            self.lineManager = lineManager
        }
        
        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            lineManager.updateLineData(from: textView)
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            lineManager.updateLineData(from: textView)
        }
    }
}
