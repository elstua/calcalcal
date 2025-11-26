import UIKit
import SwiftUI

struct BlockEditorConfiguration {
    var initialText: String = ""
}

final class BlockEditorTextView: UITextView, UITextViewDelegate {
    /// Marker character used to represent an image block in the text storage.
    /// We use the object replacement character (U+FFFC) which is what
    /// NSTextAttachment normally uses, but we don't actually attach anything.
    static let imageMarker: String = "\u{FFFC}"
    
    // MARK: - Spacing Constants (centralized to avoid inconsistency)
    
    /// Spacing for regular paragraph blocks
    private static let paragraphSpacing: CGFloat = 10
    private static let paragraphSpacingBefore: CGFloat = 10
    
    /// Spacing for image blocks when text is shorter than image (push next content below the image)
    private static let imageSpacingLarge: CGFloat = 88
    /// Spacing for image blocks when text is taller than image (text already pushed content down)
    private static let imageSpacingSmall: CGFloat = 10
    private static let imageSpacingBefore: CGFloat = 8
    
    /// Max number of text lines that still use the larger spacing.
    private static let imageLineThreshold: Int = 2
    
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
    
    /// Cached spacing decisions for image blocks: BlockID -> (lineCount, spacing).
    /// Only recalculate when the number of visual lines changes.
    private var imageSpacingCache: [BlockID: (lineCount: Int, spacing: CGFloat)] = [:]
    
    /// Flag to prevent re-entry during style application.
    private var isApplyingStyles = false
    
    init(configuration: BlockEditorConfiguration = BlockEditorConfiguration()) {
        super.init(frame: .zero, textContainer: nil)
        
        // Force lazy properties to initialize so our controllers are ready.
        _ = blockDocumentController
        _ = blockLayoutController
        
        // Observe layout changes to reposition image overlays.
        blockDocumentController.onDocumentChange = { [weak self] in
            guard let self else { return }
            
            // Clean up spacing cache for deleted blocks
            self.cleanupSpacingCache()
            
            // Re-apply paragraph styles after the document is rebuilt so every block
            // picks up the correct spacing for its kind.
            if !self.isApplyingStyles {
                self.applyBlockStyles()
            }
            
            self.updateImageOverlays()
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
        paragraphStyle.paragraphSpacingBefore = Self.paragraphSpacingBefore
        paragraphStyle.paragraphSpacing = Self.paragraphSpacing
        paragraphStyle.lineHeightMultiple = 1.14
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: baseColor,
            .paragraphStyle: paragraphStyle
        ]
        attributedText = NSAttributedString(string: configuration.initialText, attributes: attrs)
        typingAttributes = attrs
        blockDocumentController.forceRebuild()
        
        // Set self as delegate to intercept text changes (Enter key handling).
        delegate = self
        
        // Force layout invalidation so our custom layout fragments are created.
        textLayoutManager?.textViewportLayoutController.layoutViewport()
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
        paragraphStyle.paragraphSpacingBefore = Self.paragraphSpacingBefore
        paragraphStyle.paragraphSpacing = Self.paragraphSpacing
        paragraphStyle.lineHeightMultiple = 1.14
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: baseColor,
            .paragraphStyle: paragraphStyle
        ]
        attributedText = NSAttributedString(string: text, attributes: attrs)
        typingAttributes = attrs
        blockDocumentController.forceRebuild()
    }
    
    /// Helper to insert an image block at the current cursor position.
    /// Instead of using an attachment (which would affect caret size), we insert
    /// a marker character and overlay `ImageComponent` as a subview.
    /// Text flows around the image using exclusion paths (no headIndent needed).
    func insertImageBlock(image: UIImage) {
        // Generate a new block ID for this image.
        let blockID = BlockID()
        imagesByBlockID[blockID] = image
        
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        let baseColor = UIColor.label
        
        // Paragraph style for image block - NO headIndent!
        // Text will flow around the image via exclusion paths.
        // Start with large spacing (new image blocks have short text).
        let imageParagraphStyle = NSMutableParagraphStyle()
        imageParagraphStyle.paragraphSpacingBefore = Self.imageSpacingBefore
        imageParagraphStyle.paragraphSpacing = Self.imageSpacingLarge
        imageParagraphStyle.lineHeightMultiple = 1.14
        
        // Attributes for the marker character (invisible, tags the block).
        let markerAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: UIColor.clear,
            .paragraphStyle: imageParagraphStyle,
            BlockAttributeKeys.imageBlockID: blockID.rawValue
        ]
        
        // Attributes for text in the image block (same style, no indent).
        let imageTextAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: baseColor,
            .paragraphStyle: imageParagraphStyle
        ]
        
        // Normal paragraph style for text after the image block
        let normalParagraphStyle = NSMutableParagraphStyle()
        normalParagraphStyle.paragraphSpacingBefore = Self.paragraphSpacingBefore
        normalParagraphStyle.paragraphSpacing = Self.paragraphSpacing
        normalParagraphStyle.lineHeightMultiple = 1.14
        
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: baseColor,
            .paragraphStyle: normalParagraphStyle
        ]
        
        // Build: marker + sample text + newline (newline uses NORMAL style so next paragraph has normal spacing)
        let markerPart = NSAttributedString(string: Self.imageMarker, attributes: markerAttrs)
        let sampleText = NSAttributedString(string: "Description here", attributes: imageTextAttrs)
        let newlinePart = NSAttributedString(string: "\n", attributes: normalAttrs)
        
        let mutable = NSMutableAttributedString(attributedString: attributedText ?? NSAttributedString())
        let insertionIndex = max(0, min(selectedRange.location, mutable.length))
        
        mutable.insert(markerPart, at: insertionIndex)
        mutable.insert(sampleText, at: insertionIndex + 1)
        mutable.insert(newlinePart, at: insertionIndex + 1 + sampleText.length)
        
        attributedText = mutable
        blockDocumentController.forceRebuild()
        
        // Place cursor at the end of the sample text so user can edit it.
        let cursorPosition = insertionIndex + 1 + sampleText.length
        selectedRange = NSRange(location: min(cursorPosition, mutable.length), length: 0)
        
        // Set typing attributes - same style, no indent
        typingAttributes = imageTextAttrs
        
        // Trigger overlay and exclusion path update.
        updateImageOverlays()
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateImageOverlays()
    }
    
    /// Size of the image component in "small" mode
    private let imageComponentSize = CGSize(width: 72, height: 80)
    
    /// Positions `ImageComponent` overlays and sets up exclusion paths so text flows around images.
    private func updateImageOverlays() {
        // Collect current image blocks from the document.
        let imageBlocks = blockDocumentController.document.blocks.filter { $0.kind.isImage }
        
        // Remove overlays for blocks that no longer exist.
        let currentIDs = Set(imageBlocks.map { $0.id })
        for (id, host) in imageOverlays where !currentIDs.contains(id) {
            host.view.removeFromSuperview()
            imageOverlays.removeValue(forKey: id)
        }
        
        // Build exclusion paths for all image blocks
        var exclusionPaths: [UIBezierPath] = []
        
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
            let imageFrame = CGRect(
                x: textContainerInset.left,
                y: rect.minY + textContainerInset.top,
                width: imageComponentSize.width,
                height: imageComponentSize.height
            )
            host.view.frame = imageFrame
            
            // Create exclusion path for this image in text container coordinates.
            // The exclusion path is relative to the text container, not the view.
            let exclusionRect = CGRect(
                x: 0, // Start at left edge of text container
                y: rect.minY,
                width: imageComponentSize.width + 8, // Image width + padding
                height: imageComponentSize.height
            )
            let exclusionPath = UIBezierPath(rect: exclusionRect)
            exclusionPaths.append(exclusionPath)
        }
        
        // Set all exclusion paths on the text container
        textContainer.exclusionPaths = exclusionPaths
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
    
    // MARK: - Text Input Handling (UITextViewDelegate)
    
    /// Intercept text changes to fix paragraph style inheritance.
    /// When Enter is pressed, reset typingAttributes to standard BEFORE the newline is inserted.
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            // Always use standard paragraph attributes for new paragraphs.
            // Image blocks are created explicitly via insertImageBlock(), not by pressing Enter.
            typingAttributes = standardParagraphAttributes
        }
        return true
    }
    
    /// Standard paragraph attributes (no indent needed since we use exclusion paths).
    private var standardParagraphAttributes: [NSAttributedString.Key: Any] {
        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        let baseColor = UIColor.label
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = Self.paragraphSpacingBefore
        paragraphStyle.paragraphSpacing = Self.paragraphSpacing
        paragraphStyle.lineHeightMultiple = 1.14
        
        return [
            .font: baseFont,
            .foregroundColor: baseColor,
            .paragraphStyle: paragraphStyle
        ]
    }
    
    /// Called after text changes - update exclusion paths (styles are handled by document change callback).
    func textViewDidChange(_ textView: UITextView) {
        updateImageOverlays()
    }
    
    /// Called when cursor moves - set typing attributes based on current block type.
    func textViewDidChangeSelection(_ textView: UITextView) {
        let cursorLocation = selectedRange.location
        let currentBlock = blockDocumentController.block(containing: NSRange(location: cursorLocation, length: 0))
        
        // If NOT in an image block, reset typing attributes to normal
        if currentBlock == nil || !currentBlock!.kind.isImage {
            typingAttributes = standardParagraphAttributes
        }
    }
    
    /// Apply the correct paragraph style to EACH block independently.
    /// This normalizes paragraph styles after text changes (e.g., when pressing Enter
    /// splits a paragraph, the new paragraph inherits the old style and needs fixing).
    private func applyBlockStyles() {
        // Prevent re-entry
        guard !isApplyingStyles else { return }
        
        guard let textStorage = textLayoutManager?.textContentManager as? NSTextContentStorage,
              let storage = textStorage.textStorage,
              storage.length > 0 else { return }
        
        let blocks = blockDocumentController.document.blocks
        guard !blocks.isEmpty else { return }
        
        isApplyingStyles = true
        defer { isApplyingStyles = false }
        
        storage.beginEditing()
        
        for block in blocks {
            let range = block.range
            guard range.location < storage.length else { continue }
            
            // Clamp range to valid bounds
            let safeLength = min(range.length, storage.length - range.location)
            guard safeLength > 0 else { continue }
            let safeRange = NSRange(location: range.location, length: safeLength)
            
            // Determine target spacing based on block type
            let targetSpacing: CGFloat
            let targetSpacingBefore: CGFloat
            
            if block.kind.isImage {
                // For image blocks, use cached spacing or calculate if content changed
                targetSpacing = cachedSpacing(for: block)
                targetSpacingBefore = Self.imageSpacingBefore
            } else {
                targetSpacing = Self.paragraphSpacing
                targetSpacingBefore = Self.paragraphSpacingBefore
            }
            
            // Check if this range already has the correct spacing
            if let existingStyle = storage.attribute(.paragraphStyle, at: safeRange.location, effectiveRange: nil) as? NSParagraphStyle {
                // Only update if spacing is wrong (tolerance of 1 to avoid floating point issues)
                if abs(existingStyle.paragraphSpacing - targetSpacing) > 1 ||
                   abs(existingStyle.paragraphSpacingBefore - targetSpacingBefore) > 1 {
                    let newStyle = existingStyle.mutableCopy() as! NSMutableParagraphStyle
                    newStyle.paragraphSpacing = targetSpacing
                    newStyle.paragraphSpacingBefore = targetSpacingBefore
                    storage.addAttribute(.paragraphStyle, value: newStyle, range: safeRange)
                }
            }
        }
        
        storage.endEditing()
        
        // Also update typing attributes for current position
        updateTypingAttributesForCurrentBlock()
    }
    
    /// Returns cached spacing for an image block.
    /// Spacing only changes when the rendered text crosses the line threshold.
    private func cachedSpacing(for block: BlockMetadata) -> CGFloat {
        let currentLineCount = lineCount(for: block)
        
        if let cached = imageSpacingCache[block.id], cached.lineCount == currentLineCount {
            return cached.spacing
        }
        
        let spacing = currentLineCount <= Self.imageLineThreshold ? Self.imageSpacingLarge : Self.imageSpacingSmall
        imageSpacingCache[block.id] = (lineCount: currentLineCount, spacing: spacing)
        return spacing
    }
    
    /// Removes stale entries from the spacing cache (blocks that no longer exist).
    private func cleanupSpacingCache() {
        let currentImageBlockIDs = Set(blockDocumentController.document.blocks.filter { $0.kind.isImage }.map { $0.id })
        imageSpacingCache = imageSpacingCache.filter { currentImageBlockIDs.contains($0.key) }
    }
    
    /// Returns the rendered line count for a block's text content.
    /// Uses TextKit 2 layout fragments to count actual line fragments.
    private func lineCount(for block: BlockMetadata) -> Int {
        guard let textLayoutManager = textLayoutManager,
              let contentManager = textLayoutManager.textContentManager,
              let textStorage = (contentManager as? NSTextContentStorage)?.textStorage else {
            return 1
        }
        
        // Ensure layout reflects the latest edits.
        textLayoutManager.textViewportLayoutController.layoutViewport()
        
        guard block.range.location < textStorage.length else { return 1 }
        let availableLength = textStorage.length - block.range.location
        guard availableLength > 0 else { return 1 }
        let safeLength = max(1, min(block.range.length, availableLength))
        
        let docRange = contentManager.documentRange
        guard let startLocation = contentManager.location(docRange.location, offsetBy: block.range.location),
              let endLocation = contentManager.location(startLocation, offsetBy: safeLength),
              let textRange = NSTextRange(location: startLocation, end: endLocation) else {
            return 1
        }
        
        var totalLines = 0
        textLayoutManager.enumerateTextLayoutFragments(from: textRange.location,
                                                       options: [.ensuresLayout, .ensuresExtraLineFragment]) { fragment in
            let fragmentRange = fragment.rangeInElement
            let fragmentEnd = fragmentRange.endLocation
            
            guard fragmentEnd.compare(textRange.endLocation) != .orderedDescending else {
                return false
            }
            
            totalLines += fragment.textLineFragments.count
            return true
        }
        
        return max(totalLines, 1)
    }
    
    /// Set typing attributes based on current block type.
    private func updateTypingAttributesForCurrentBlock() {
        let cursorLocation = selectedRange.location
        let currentBlock = blockDocumentController.block(containing: NSRange(location: cursorLocation, length: 0))
        
        if let block = currentBlock, block.kind.isImage {
            // In image block - use cached spacing
            let spacing = cachedSpacing(for: block)
            
            let baseFont = UIFont.preferredFont(forTextStyle: .body)
            let baseColor = UIColor.label
            let style = NSMutableParagraphStyle()
            style.paragraphSpacingBefore = Self.imageSpacingBefore
            style.paragraphSpacing = spacing
            style.lineHeightMultiple = 1.14
            
            typingAttributes = [
                .font: baseFont,
                .foregroundColor: baseColor,
                .paragraphStyle: style
            ]
        } else {
            // In paragraph block or new position - use standard spacing
            typingAttributes = standardParagraphAttributes
        }
    }
}

