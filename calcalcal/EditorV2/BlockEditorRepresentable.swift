#if canImport(SwiftUI)
import SwiftUI
import UIKit

@available(iOS 16.0, *)
struct BlockEditorRepresentable: UIViewRepresentable {
    @Binding var text: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> BlockEditorTextView {
        let view = BlockEditorTextView(configuration: BlockEditorConfiguration(initialText: text))
        view.delegate = context.coordinator
        context.coordinator.textView = view
        return view
    }
    
    func updateUIView(_ uiView: BlockEditorTextView, context: Context) {
        context.coordinator.isSyncingFromSwiftUI = true
        uiView.updateTextIfNeeded(text)
        context.coordinator.isSyncingFromSwiftUI = false
    }
    
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: BlockEditorRepresentable
        weak var textView: BlockEditorTextView?
        var isSyncingFromSwiftUI = false
        
        init(parent: BlockEditorRepresentable) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            guard !isSyncingFromSwiftUI else { return }
            parent.text = textView.text
        }
    }
}

@available(iOS 16.0, *)
struct BlockEditorDemoView: View {
    @State private var text: String = """
    Oatmeal with berries
    Chicken salad with avocado
    Cappuccino
    """
    
    var body: some View {
        VStack(spacing: 12) {
            BlockEditorRepresentable(text: $text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            
            Text("Blocks: \(text.components(separatedBy: .newlines).filter { !$0.isEmpty }.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

#endif