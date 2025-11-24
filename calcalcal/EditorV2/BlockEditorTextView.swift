import UIKit
import SwiftUI

struct BlockEditorConfiguration {
    var initialText: String = ""
}

final class BlockEditorTextView: UITextView {
    /// Marker character used to represent an image block in the text storage.
    /// We use the object replacement character (U+FFFC) which is what
    /// NSTextAttachment normally uses, but we don't actually attach anything.
    static let imageMarker: String = "\u{FFFC}"
    
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
    
    /// Maps BlockID to the overlay hosting controller for image blocks.
    private var imageOverlays: [BlockID: UIHostingController<ImageComponent>] = [:]
    
    /// Images associated with block IDs (set when inserting image blocks).
    private var imagesByBlockID: [BlockID: UIImage] = [:]
    
    init(configuration: BlockEditorConfiguration = BlockEditorConfiguration()) {
        super.init(frame: .zero, textContainer: nil)
        
        // Force lazy properties to initialize so our controllers are ready.
        _ = blockDocumentController
        _ = blockLayoutController
        
        // Observe layout changes to reposition image overlays.
        blockDocumentController.onDocumentChange = { [weak self] in
            self?.updateImageOverlays()
        }
        
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
    
    /// Helper to insert an image block at the current cursor position.
    /// Instead of using an attachment (which would affect caret size), we insert
    /// a marker character and overlay `ImageComponent` as a subview.
    /// Text in the same paragraph flows to the right of the image via `headIndent`.
    func insertImageBlock(image: UIImage) {
        // Generate a new block ID for this image.
        let blockID = BlockID()
        imagesByBlockID[blockID] = image
        
        // ImageComponent small mode width + some padding.
        let imageWidth: CGFloat = 100
        let textIndent: CGFloat = imageWidth + 12
        
        // Paragraph style for the image block line: text starts after the image.
        let imageParagraphStyle = NSMutableParagraphStyle()
        imageParagraphStyle.paragraphSpacingBefore = 20
        imageParagraphStyle.paragraphSpacing = 20
        imageParagraphStyle.lineHeightMultiple = 1.14
        imageParagraphStyle.headIndent = textIndent
        imageParagraphStyle.firstLineHeadIndent = textIndent
        
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        let baseColor = UIColor.label
        
        // Attributes for the marker character only (invisible, but reserves space via kern).
        let markerAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: UIColor.clear, // Marker is invisible; overlay shows the image.
            .paragraphStyle: imageParagraphStyle,
            BlockAttributeKeys.imageBlockID: blockID.rawValue
        ]
        
        // Attributes for text in the image block (visible, same paragraph style).
        let imageTextAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: baseColor,
            .paragraphStyle: imageParagraphStyle
        ]
        
        // Normal text attributes for the next paragraph.
        let normalParagraphStyle = NSMutableParagraphStyle()
        normalParagraphStyle.paragraphSpacingBefore = 12
        normalParagraphStyle.paragraphSpacing = 12
        normalParagraphStyle.lineHeightMultiple = 1.14
        
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: baseColor,
            .paragraphStyle: normalParagraphStyle
        ]
        
        // Build: marker (invisible) + sample text (visible, indented) + newline (normal for next para).
        let markerPart = NSAttributedString(string: Self.imageMarker, attributes: markerAttrs)
        let sampleText = NSAttributedString(string: "Description here", attributes: imageTextAttrs)
        let newlinePart = NSAttributedString(string: "\n", attributes: normalAttrs)
        
        let mutable = NSMutableAttributedString(attributedString: attributedText ?? NSAttributedString())
        let insertionIndex = max(0, min(selectedRange.location, mutable.length))
        
        mutable.insert(markerPart, at: insertionIndex)
        mutable.insert(sampleText, at: insertionIndex + 1)
        mutable.insert(newlinePart, at: insertionIndex + 1 + sampleText.length)
        
        attributedText = mutable
        
        // Place cursor at the end of the sample text so user can edit it.
        let cursorPosition = insertionIndex + 1 + sampleText.length
        selectedRange = NSRange(location: min(cursorPosition, mutable.length), length: 0)
        
        // Set typing attributes to the image block style so continued typing stays indented.
        typingAttributes = imageTextAttrs
        
        // Trigger overlay update.
        updateImageOverlays()
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateImageOverlays()
    }
    
    /// Positions `ImageComponent` overlays based on the layout rect of each
    /// image block's marker character.
    private func updateImageOverlays() {
        // Collect current image blocks from the document.
        let imageBlocks = blockDocumentController.document.blocks.filter { $0.kind.isImage }
        
        // Remove overlays for blocks that no longer exist.
        let currentIDs = Set(imageBlocks.map { $0.id })
        for (id, host) in imageOverlays where !currentIDs.contains(id) {
            host.view.removeFromSuperview()
            imageOverlays.removeValue(forKey: id)
        }
        
        // Create or update overlays for each image block.
        for block in imageBlocks {
            guard let uiImage = imageForBlock(block) else { continue }
            guard let rect = rectForBlock(block) else { continue }
            
            let host: UIHostingController<ImageComponent>
            if let existing = imageOverlays[block.id] {
                host = existing
            } else {
                let view = ImageComponent(
                    uiImage: uiImage,
                    isLarge: false,
                    onDelete: nil,
                    onLongPress: nil
                )
                host = UIHostingController(rootView: view)
                host.view.backgroundColor = .clear
                addSubview(host.view)
                imageOverlays[block.id] = host
            }
            
            // Position the overlay at the left edge of the text container,
            // aligned vertically with the marker's line.
            // ImageComponent small mode is 100x120.
            let componentSize = CGSize(width: 100, height: 120)
            host.view.frame = CGRect(
                x: textContainerInset.left,
                y: rect.minY + textContainerInset.top,
                width: componentSize.width,
                height: componentSize.height
            )
        }
    }
    
    /// Returns the image associated with a block (looked up by custom attribute
    /// or by our local map).
    private func imageForBlock(_ block: BlockMetadata) -> UIImage? {
        // First check our local map.
        if let img = imagesByBlockID[block.id] {
            return img
        }
        // Fallback: check if BlockMetadata carries the image.
        return block.image
    }
    
    /// Returns the bounding rect for the first character of a block's range.
    private func rectForBlock(_ block: BlockMetadata) -> CGRect? {
        guard let textLayoutManager = textLayoutManager else { return nil }
        guard let contentManager = textLayoutManager.textContentManager else { return nil }
        
        let docRange = contentManager.documentRange
        guard let startLocation = contentManager.location(docRange.location, offsetBy: block.range.location) else {
            return nil
        }
        guard let endLocation = contentManager.location(startLocation, offsetBy: 1) else {
            return nil
        }
        guard let textRange = NSTextRange(location: startLocation, end: endLocation) else {
            return nil
        }
        
        var rect: CGRect?
        textLayoutManager.enumerateTextSegments(in: textRange, type: .standard, options: []) { _, segmentRect, _, _ in
            rect = segmentRect
            return false // stop after first
        }
        return rect
    }
}

