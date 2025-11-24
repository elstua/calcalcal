import UIKit
import SwiftUI

struct BlockEditorConfiguration {
    var initialText: String = ""
}

final class BlockEditorTextView: UITextView {
    // Lazily constructed after TextKit 2 stack is available.
    lazy var blockDocumentController: BlockDocumentController = {
        guard
            let textLayoutManager = self.textLayoutManager,
            let contentManager = textLayoutManager.textContentManager,
            let textContentStorage = contentManager as? NSTextContentStorage,
            let textStorage = textContentStorage.textStorage
        else {
            fatalError("Expected TextKit 2 stack with NSTextContentStorage and NSTextStorage")
        }
        return BlockDocumentController(textStorage: textStorage, contentManager: contentManager)
    }()
    
    lazy var blockLayoutController: BlockTextLayoutController = {
        let controller = BlockTextLayoutController(documentController: blockDocumentController)
        if let textLayoutManager = self.textLayoutManager {
            controller.attach(to: textLayoutManager)
        }
        return controller
    }()
    
    init(configuration: BlockEditorConfiguration = BlockEditorConfiguration()) {
        super.init(frame: .zero, textContainer: nil)
        
        // Force lazy properties to initialize so our controllers are ready.
        _ = blockDocumentController
        _ = blockLayoutController
        
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        
        backgroundColor = .clear
        alwaysBounceVertical = true
        contentInsetAdjustmentBehavior = .automatic
        textDragInteraction?.isEnabled = true
        isScrollEnabled = true
        allowsEditingTextAttributes = false
        smartInsertDeleteType = .yes
        spellCheckingType = .yes
        autocorrectionType = .yes
        
        // Build a paragraph style with spacing that will be inherited by every
        // new paragraph as the user types. This keeps the storage and layout in
        // sync so caret/selection geometry matches what's drawn on screen.
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        let baseColor = UIColor.label
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = 12
        paragraphStyle.paragraphSpacing = 12
        paragraphStyle.lineHeightMultiple = 1.14
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: baseColor,
            .paragraphStyle: paragraphStyle
        ]
        attributedText = NSAttributedString(string: configuration.initialText, attributes: attrs)
        typingAttributes = attrs
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateTextIfNeeded(_ text: String) {
        guard self.text != text else { return }
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        let baseColor = UIColor.label
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = 12
        paragraphStyle.paragraphSpacing = 12
        paragraphStyle.lineHeightMultiple = 1.14
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: baseColor,
            .paragraphStyle: paragraphStyle
        ]
        attributedText = NSAttributedString(string: text, attributes: attrs)
        typingAttributes = attrs
    }
    
    /// Helper to insert an image block at the current cursor position,
    /// rendering via `ImageComponent` (small / polaroid style).
    func insertImageBlock(image: UIImage) {
        // Render ImageComponent to a UIImage so we can use it as an attachment.
        let imageComponentView = ImageComponent(
            uiImage: image,
            isLarge: false,
            onDelete: nil,
            onLongPress: nil
        )
        let hostingController = UIHostingController(rootView: imageComponentView)
        hostingController.view.backgroundColor = .clear
        
        // ImageComponent small mode is 100x120 per the component definition.
        let componentSize = CGSize(width: 100, height: 120)
        hostingController.view.frame = CGRect(origin: .zero, size: componentSize)
        hostingController.view.layoutIfNeeded()
        
        // Snapshot the SwiftUI view into a UIImage.
        let renderer = UIGraphicsImageRenderer(size: componentSize)
        let renderedImage = renderer.image { _ in
            hostingController.view.drawHierarchy(in: CGRect(origin: .zero, size: componentSize), afterScreenUpdates: true)
        }
        
        let attachment = NSTextAttachment()
        attachment.image = renderedImage
        attachment.bounds = CGRect(x: 0, y: 0, width: componentSize.width, height: componentSize.height)
        
        // Build paragraph style with larger spacing for image blocks.
        let imageParagraphStyle = NSMutableParagraphStyle()
        imageParagraphStyle.paragraphSpacingBefore = 20
        imageParagraphStyle.paragraphSpacing = 20
        imageParagraphStyle.lineHeightMultiple = 1.14
        
        let imageAttrs: [NSAttributedString.Key: Any] = [
            .font: font ?? UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: textColor ?? UIColor.label,
            .paragraphStyle: imageParagraphStyle
        ]
        
        let attachmentString = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))
        attachmentString.addAttributes(imageAttrs, range: NSRange(location: 0, length: attachmentString.length))
        
        let spacer = NSAttributedString(string: "  ", attributes: imageAttrs)
        let textPart = NSAttributedString(string: "Sample text near image\n", attributes: imageAttrs)
        
        let mutable = NSMutableAttributedString(attributedString: attributedText ?? NSAttributedString())
        let insertionIndex = max(0, min(selectedRange.location, mutable.length))
        
        mutable.insert(attachmentString, at: insertionIndex)
        mutable.insert(spacer, at: insertionIndex + 1)
        mutable.insert(textPart, at: insertionIndex + 2)
        
        attributedText = mutable
        selectedRange = NSRange(location: min(insertionIndex + 3, mutable.length), length: 0)
    }
}

