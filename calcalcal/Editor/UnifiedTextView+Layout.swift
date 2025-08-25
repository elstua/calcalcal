import UIKit
#if canImport(SwiftUI)
import SwiftUI
#endif


// MARK: - Layout Management Extension

extension UnifiedTextView {
    
    // MARK: - TextKit Compatibility Helper
    
    /// Get bounding rect for character range without TextKit 1 APIs
    internal func boundingRect(for characterRange: NSRange) -> CGRect {
        // Ensure the range is valid
        guard characterRange.location < textStorage.length else { return .zero }
        
        // Prefer using UITextInput selection rects (respects exclusions, attachments, wrapping)
        if let start = position(from: beginningOfDocument, offset: characterRange.location),
           let end = position(from: start, offset: characterRange.length),
           let range = textRange(from: start, to: end) {
            let rects = selectionRects(for: range)
            var unionRect: CGRect = .null
            for r in rects where !r.rect.isEmpty {
                unionRect = unionRect.union(r.rect)
            }
            if !unionRect.isNull && !unionRect.isEmpty {
                // Already in view coordinates; return as-is
                return unionRect
            }
        }
        
        // Fallback: approximate using attributed measurement
        let font = self.font ?? UIFont.systemFont(ofSize: 16)
        let lineHeight = font.lineHeight
        let containerWidth = textContainer.size.width - textContainer.lineFragmentPadding * 2
        let string = textStorage.string as NSString
        let paragraphText = string.substring(with: characterRange)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: self.textColor ?? UIColor.label
        ]
        let attributedParagraph = NSAttributedString(string: paragraphText, attributes: attributes)
        let constraintSize = CGSize(width: containerWidth, height: CGFloat.greatestFiniteMagnitude)
        let boundingSize = attributedParagraph.boundingRect(
            with: constraintSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        let textBeforeRange = string.substring(to: characterRange.location)
        let attributedTextBefore = NSAttributedString(string: textBeforeRange, attributes: attributes)
        let heightBefore = attributedTextBefore.boundingRect(
            with: constraintSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size.height
        return CGRect(x: textContainerInset.left, y: textContainerInset.top + heightBefore, width: containerWidth, height: max(boundingSize.height, lineHeight))
    }
    
    /// Invalidate layout for character range using appropriate API
    private func invalidateLayout(for characterRange: NSRange) {
        // Avoid layoutManager invalidations to keep TextKit 2 mode
        setNeedsDisplay()
        setNeedsLayout()
    }
    
    // MARK: - Exclusion Path Management
    
    /// Update exclusion paths for image-text blocks
    internal func updateExclusionPaths() {
        var exclusionPaths: [UIBezierPath] = []
        let string = textStorage.string as NSString
        guard string.length > 0 else {
            textContainer.exclusionPaths = []
            return
        }
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard let metadata = metadata, paragraphRange.location < string.length, NSMaxRange(paragraphRange) <= string.length else { return }
            let paragraphText = string.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraphText.isEmpty else { return }
            if metadata.blockType == .imageText {
                let provider = layoutProvider(for: metadata.blockType)
                exclusionPaths.append(contentsOf: provider.exclusionPaths(for: paragraphRange, in: self, metadata: metadata))
            }
        }
        textContainer.exclusionPaths = exclusionPaths
        setNeedsLayout()
        setNeedsDisplay()
    }
    
    // MARK: - Image View Management
    
    /// Update image views for image-text blocks
    internal func updateImageViews() {
        // Remove image views that no longer exist
        var currentImageRefs = Set<UUID>()
        let string = textStorage.string as NSString
        guard string.length > 0 else {
            for (_, imageView) in imageViews {
                imageView.removeFromSuperview()
            }
            imageViews.removeAll()
            return
        }
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard let metadata = metadata,
                  metadata.blockType == .imageText,
                  let imageRef = metadata.imageReference,
                  paragraphRange.location < string.length,
                  NSMaxRange(paragraphRange) <= string.length else { return }
            let paragraphText = string.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraphText.isEmpty else { return }
            currentImageRefs.insert(imageRef)
        }
        for (imageRef, imageView) in imageViews {
            if !currentImageRefs.contains(imageRef) {
                imageView.removeFromSuperview()
                imageViews.removeValue(forKey: imageRef)
            }
        }
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard let metadata = metadata,
                  metadata.blockType == .imageText,
                  let imageRef = metadata.imageReference,
                  paragraphRange.location < string.length,
                  NSMaxRange(paragraphRange) <= string.length else { return }
            let paragraphText = string.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraphText.isEmpty else { return }
            let boundingRect = self.boundingRect(for: paragraphRange)
            let containerWidth = self.textContainer.size.width - self.textContainer.lineFragmentPadding * 2
            let imageWidth = containerWidth * 0.3
            var imageHeight: CGFloat = max(100, boundingRect.height)
            var imageFrame = CGRect(
                x: 0,
                y: boundingRect.origin.y, // Always anchor to top of block
                width: imageWidth,
                height: imageHeight
            )
            imageFrame.origin.x += self.textContainerInset.left + self.textContainer.lineFragmentPadding
            imageFrame.origin.y += self.textContainerInset.top
            imageFrame.size.width -= 8
            let imageView: UIView
            if let existingView = imageViews[imageRef] {
                imageView = existingView
            } else {
                if let image = self.imageMap[imageRef] {
                    // Use image aspect ratio for height if possible
                    let aspectRatio = image.size.height / max(image.size.width, 1)
                    imageHeight = min(max(imageWidth * aspectRatio, 100), 420) // Cap height
                    imageFrame.size.height = imageHeight
                    let imageViewObj = UIImageView(image: image)
                    imageViewObj.contentMode = .scaleAspectFill
                    imageViewObj.clipsToBounds = true
                    imageViewObj.layer.cornerRadius = 4.0
                    imageView = imageViewObj
                } else {
                    imageView = createImagePlaceholderView(imageWidth: imageWidth, imageHeight: imageHeight)
                }
                imageViews[imageRef] = imageView
                addSubview(imageView)
            }
            imageView.frame = imageFrame
        }
    }
    
    /// Create a placeholder image view
    internal func createImagePlaceholderView(imageWidth: CGFloat = 100, imageHeight: CGFloat = 120) -> UIView {
        // #if canImport(SwiftUI)
        // let imageComponent = ImageComponent(uiImage: nil, isLarge: false, onDelete: nil, onLongPress: nil)
        // let hostingController = UIHostingController(rootView: imageComponent.frame(width: imageWidth, height: imageHeight))
        // hostingController.view.backgroundColor = UIColor.clear
        // hostingController.view.frame = CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
        // return hostingController.view
        // #else
        let view = UIView()
        view.backgroundColor = UIColor.systemGray4
        view.layer.cornerRadius = 4.0
        view.frame = CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
        return view
        // #endif
    }
    
    // MARK: - Block Background Management
    
    /// Update block background views
    internal func updateBlockBackgroundViews() {
        // Remove block background views that no longer exist
        var currentBlockKeys = Set<String>()
        
        // Only process paragraphs that have actual content
        let string = textStorage.string as NSString
        guard string.length > 0 else {
            // Remove all background views if no content
            for (_, backgroundView) in blockBackgroundViews {
                backgroundView.removeFromSuperview()
            }
            blockBackgroundViews.removeAll()
            return
        }
        
        // First, collect all current block keys (based on paragraph range) from valid paragraphs
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard let metadata = metadata,
                  paragraphRange.location < string.length else { return }
            
            // Verify the paragraph actually contains text
            let paragraphText = string.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraphText.isEmpty else { return }
            
            let blockKey = "\(paragraphRange.location):\(paragraphRange.length)"
            currentBlockKeys.insert(blockKey)
        }
        
        // Remove views for blocks that no longer exist
        for (blockKey, backgroundView) in blockBackgroundViews {
            if !currentBlockKeys.contains(blockKey) && !blockKey.contains("_separator") {
                backgroundView.removeFromSuperview()
                blockBackgroundViews.removeValue(forKey: blockKey)
                
                // Also remove associated separator
                let separatorKey = blockKey + "_separator"
                if let separatorView = blockBackgroundViews[separatorKey] {
                    separatorView.removeFromSuperview()
                    blockBackgroundViews.removeValue(forKey: separatorKey)
                }
            }
        }
        
        // Update positions for existing blocks and create new ones
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard let metadata = metadata,
                  paragraphRange.location < string.length else { return }
            let paragraphText = string.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraphText.isEmpty else { return }
            let blockKey = "\(paragraphRange.location):\(paragraphRange.length)"
            let boundingRect = self.boundingRect(for: paragraphRange)
            var blockFrame = boundingRect
            blockFrame.origin.x += self.textContainerInset.left
            blockFrame.origin.y += self.textContainerInset.top
            let totalBlockWidth = self.bounds.width - self.textContainerInset.left - self.textContainerInset.right
            // Use provider for block-specific sizing
            let provider = layoutProvider(for: metadata.blockType)
            if metadata.blockType == .imageText {
                blockFrame.size.height = max(100, blockFrame.height)
                blockFrame.size.width = totalBlockWidth
                blockFrame.origin.x = self.textContainerInset.left
            } else {
                blockFrame.size.width = totalBlockWidth
            }
            blockFrame = blockFrame.insetBy(dx: 0, dy: 3)
            let backgroundView: UIView
            if let existingView = blockBackgroundViews[blockKey] {
                backgroundView = existingView
            } else {
                backgroundView = createBlockBackgroundView(for: metadata.blockType)
                blockBackgroundViews[blockKey] = backgroundView
                insertSubview(backgroundView, at: 0)
            }
            backgroundView.frame = blockFrame
//            updateBlockBackgroundAppearance(backgroundView, for: metadata.blockType)
            backgroundView.subviews.filter { $0 is CalorieLabelView }.forEach { $0.removeFromSuperview() }
            // Show placeholder when no backend calories yet
            let caloriesText = metadata.calorieData ?? "…"
            let calorieLabel = CalorieLabelView()
            calorieLabel.setCalories(caloriesText)
            if let calorieLabelFrame = provider.calorieLabelFrame(for: paragraphRange, in: self, metadata: metadata, blockFrame: blockFrame) {
                calorieLabel.frame = calorieLabelFrame
            }
            backgroundView.addSubview(calorieLabel)
        }
    }
    
    /// Create a block background view
    private func createBlockBackgroundView(for blockType: UnifiedTextContentStorage.BlockMetadata.BlockType) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false // Don't interfere with text editing
//        updateBlockBackgroundAppearance(view, for: blockType)
        return view
    }
    
    /// Update block background view appearance
//    private func updateBlockBackgroundAppearance(_ view: UIView, for blockType: UnifiedTextContentStorage.BlockMetadata.BlockType) {
//        switch blockType {
//        case .text:
//            // Green tint for text blocks
//            view.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.05)
//        case .imageText:
//            // Blue tint for image blocks
//            view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.05)
//        case .spacer:
//            // Gray tint for spacer blocks (more visible for debug)
//            view.backgroundColor = UIColor.systemGray.withAlphaComponent(0.25)
//        }
//    }
}

class CalorieLabelView: UIView {
    private let label = UILabel()
    init() {
        super.init(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .systemGray
        label.textAlignment = .right
        label.isUserInteractionEnabled = false
        label.numberOfLines = 1
        label.lineBreakMode = .byClipping
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func setCalories(_ calories: String) {
        label.text = calories
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds
    }
}

// --- Helper to get last line rect for a paragraph ---
extension UnifiedTextView {
    /// Returns the rect (in view coordinates) for the last line of a paragraph range
    func lastLineRect(for paragraphRange: NSRange) -> CGRect? {
        guard paragraphRange.length > 0 else { return nil }
        if let start = position(from: beginningOfDocument, offset: paragraphRange.location),
           let end = position(from: start, offset: paragraphRange.length),
           let range = textRange(from: start, to: end) {
            let rects = selectionRects(for: range)
            if let last = rects.last?.rect, !last.isEmpty { return last }
        }
        // Fallback: derive from boundingRect
        let rect = boundingRect(for: paragraphRange)
        return CGRect(
            x: rect.origin.x + textContainerInset.left,
            y: rect.origin.y + textContainerInset.top + max(0, rect.height - (self.font?.lineHeight ?? 16)),
            width: rect.width,
            height: self.font?.lineHeight ?? 16
        )
    }
}

// Helper to get the correct layout provider
private func layoutProvider(for blockType: UnifiedTextContentStorage.BlockMetadata.BlockType) -> BlockLayoutProviding {
    switch blockType {
    case .text:
        return TextBlockLayout()
    case .imageText:
        return ImageTextBlockLayout()
    case .spacer:
        return TextBlockLayout() // Or create a SpacerBlockLayout if needed
    }
} 
