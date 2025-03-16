import SwiftUI
import UIKit

struct CalorieTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var totalCalories: Int
    @Binding var isEditing: Bool
    
    var calculateCalories: (String, @escaping (Int) -> Void) -> Void
    
    func makeUIView(context: Context) -> CalorieTextView {
        let textView = CalorieTextView(frame: .zero, textContainer: nil)
        textView.delegate = context.coordinator
        textView.text = text
        
        // Configure text change callback
        textView.onTextChanged = { newText in
            DispatchQueue.main.async {
                // Only update if text differs to avoid loops
                if self.text != newText {
                    self.text = newText
                }
            }
        }
        
        // Configure calorie calculation
        textView.onNeedCalorieCalculation = calculateCalories
        
        // Handle total calorie updates
        textView.onTotalCaloriesChanged = { calories in
            DispatchQueue.main.async {
                self.totalCalories = calories
            }
        }
        
        // Configure appearance
        textView.font = .systemFont(ofSize: 18)
        textView.isScrollEnabled = true
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .yes
        textView.keyboardType = .default
        textView.returnKeyType = .default
        textView.smartDashesType = .yes
        textView.smartQuotesType = .yes
        textView.smartInsertDeleteType = .yes
        textView.spellCheckingType = .yes
        
        return textView
    }
    
    func updateUIView(_ textView: CalorieTextView, context: Context) {
        // Only update if text differs to avoid cursor jumping
        if textView.text != text {
            textView.text = text
            
            // If text was set externally, recalculate paragraphs
            textView.recalculateAllParagraphs()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CalorieTextEditor
        
        init(_ parent: CalorieTextEditor) {
            self.parent = parent
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isEditing = true
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isEditing = false
        }
    }
}
