import UIKit

import SwiftUI

final class PlainAttachmentTextView: UITextView {
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: .zero, textContainer: nil)
        
        // Use default TextKit 2 stack configured by UITextView itself.
        font = UIFont.dsBody
        isScrollEnabled = true
        alwaysBounceVertical = true
        backgroundColor = .dsBackground
        smartInsertDeleteType = .yes
        spellCheckingType = .yes
        autocorrectionType = .yes
        
        text = """
        This is a plain TextKit 2 UITextView.
        Type around and then insert an image attachment to verify stability.
        """
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Simple helper to insert a sample image attachment at the current cursor position.
    func insertSampleImageAttachment() {
        guard let image = UIImage(systemName: "photo") else { return }
        
        let attachment = NSTextAttachment()
        attachment.image = image
        
        // Match the compact image sizing we use in ImageComponent small mode.
        let maxWidth: CGFloat = 86
        let aspectRatio: CGFloat
        if image.size.width > 0 {
            aspectRatio = image.size.height / image.size.width
        } else {
            aspectRatio = 1.0
        }
        let height = maxWidth * aspectRatio
        attachment.bounds = CGRect(x: 0, y: 0, width: maxWidth, height: height)
        
        let attachmentString = NSAttributedString(attachment: attachment)
        let spacer = NSAttributedString(string: "  ", attributes: [.font: font ?? UIFont.dsBody])
        
        // Insert into the existing attributed text at the caret position.
        let mutable = NSMutableAttributedString(attributedString: attributedText ?? NSAttributedString())
        let insertionIndex = max(0, min(selectedRange.location, mutable.length))
        
        mutable.insert(attachmentString, at: insertionIndex)
        mutable.insert(spacer, at: insertionIndex + 1)
        
        attributedText = mutable
        
        // Move the caret after the inserted content.
        selectedRange = NSRange(location: min(insertionIndex + 2, mutable.length), length: 0)
    }
}


struct PlainAttachmentTextViewRepresentable: UIViewRepresentable {
    var onTextViewCreated: ((PlainAttachmentTextView) -> Void)? = nil
    
    func makeUIView(context: Context) -> PlainAttachmentTextView {
        let view = PlainAttachmentTextView()
        onTextViewCreated?(view)
        return view
    }
    
    func updateUIView(_ uiView: PlainAttachmentTextView, context: Context) {
        // No-op: for this isolation test, UITextView is the source of truth.
    }
}

struct PlainAttachmentEditorTestView: View {
    @State private var textView: PlainAttachmentTextView?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: DSSpacing.md) {
                PlainAttachmentTextViewRepresentable { tv in
                    self.textView = tv
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DSColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.lg, style: .continuous))
                
                Button("Insert sample image (plain TK2)") {
                    textView?.insertSampleImageAttachment()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(DSSpacing.mlg)
            .navigationTitle("Plain Attachment Test")
        }
    }
}

struct PlainAttachmentEditorTestView_Previews: PreviewProvider {
    static var previews: some View {
        PlainAttachmentEditorTestView()
    }
}

