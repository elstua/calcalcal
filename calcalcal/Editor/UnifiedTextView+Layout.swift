import UIKit


// MARK: - Layout Management Extension

extension UnifiedTextView {
    
    // MARK: - TextKit Compatibility Helper
    
    /// Get bounding rect for character range using proper text measurement
    internal func boundingRect(for characterRange: NSRange) -> CGRect {
        // Ensure the range is valid
        guard characterRange.location < textStorage.length else {
            return CGRect.zero
        }
        
        // Get the actual paragraph text for this range
        let string = textStorage.string as NSString
        let paragraphText = string.substring(with: characterRange)
        
        // Use TextKit 1 for accurate measurements when we need precise positioning
        // This is necessary for proper block positioning and sizing
        let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // If TextKit 1 gives us a valid rect, use it
        if !boundingRect.isEmpty {
            return boundingRect
        }
        
        // Fallback to manual calculation if TextKit 1 fails
        let font = self.font ?? UIFont.systemFont(ofSize: 16)
        let lineHeight = font.lineHeight
        
        // Calculate the actual number of lines this paragraph will take
        let containerWidth = textContainer.size.width - textContainer.lineFragmentPadding * 2
        
        // Create a temporary text storage to measure the paragraph
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: self.textColor ?? UIColor.label
        ]
        
        let attributedParagraph = NSAttributedString(string: paragraphText, attributes: attributes)
        
        // Calculate the height needed for this text
        let constraintSize = CGSize(width: containerWidth, height: CGFloat.greatestFiniteMagnitude)
        let boundingSize = attributedParagraph.boundingRect(
            with: constraintSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        
        // Calculate Y position by measuring all text before this range
        let textBeforeRange = string.substring(to: characterRange.location)
        let attributedTextBefore = NSAttributedString(string: textBeforeRange, attributes: attributes)
        let heightBefore = attributedTextBefore.boundingRect(
            with: constraintSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size.height
        
        return CGRect(
            x: 0,
            y: heightBefore,
            width: containerWidth,
            height: max(boundingSize.height, lineHeight) // Ensure minimum height
        )
    }
    
    /// Invalidate layout for character range using appropriate API
    private func invalidateLayout(for characterRange: NSRange) {
        // For most cases, we can simply trigger a redraw without accessing layoutManager
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
            let provider = layoutProvider(for: metadata.blockType)
            exclusionPaths.append(contentsOf: provider.exclusionPaths(for: paragraphRange, in: self, metadata: metadata))
        }
        textContainer.exclusionPaths = exclusionPaths
        layoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textStorage.length), actualCharacterRange: nil)
        layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textStorage.length))
        layoutManager.ensureLayout(forCharacterRange: NSRange(location: 0, length: textStorage.length))
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
            let imageHeight = max(100, boundingRect.height)
            var imageFrame = CGRect(
                x: 0,
                y: boundingRect.origin.y,
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
                imageView = createImagePlaceholderView()
                imageViews[imageRef] = imageView
                addSubview(imageView)
            }
            imageView.frame = imageFrame
        }
    }
    
    /// Create a placeholder image view
    internal func createImagePlaceholderView() -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray4
        view.layer.borderColor = UIColor.systemGray3.cgColor
        view.layer.borderWidth = 1.0
        view.layer.cornerRadius = 4.0
        
        // Add icon and label
        let iconSize: CGFloat = 24
        let iconView = UIView()
        iconView.backgroundColor = .clear
        iconView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconView)
        
        let label = UILabel()
        label.text = "Add Image"
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = UIColor.systemGray2
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -10),
            iconView.widthAnchor.constraint(equalToConstant: iconSize),
            iconView.heightAnchor.constraint(equalToConstant: iconSize),
            
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            label.leftAnchor.constraint(greaterThanOrEqualTo: view.leftAnchor, constant: 4),
            label.rightAnchor.constraint(lessThanOrEqualTo: view.rightAnchor, constant: -4)
        ])
        
        // Custom drawing for the icon (we'll do this in a custom view)
        iconView.layer.borderColor = UIColor.systemGray2.cgColor
        iconView.layer.borderWidth = 2.0
        
        return view
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
            updateBlockBackgroundAppearance(backgroundView, for: metadata.blockType)
            backgroundView.subviews.filter { $0 is CalorieLabelView }.forEach { $0.removeFromSuperview() }
            if let calories = metadata.calorieData {
                let calorieLabel = CalorieLabelView()
                calorieLabel.setCalories(calories)
                if let calorieLabelFrame = provider.calorieLabelFrame(for: paragraphRange, in: self, metadata: metadata, blockFrame: blockFrame) {
                    calorieLabel.frame = calorieLabelFrame
                }
                backgroundView.addSubview(calorieLabel)
            } else {
                print("[CalorieLabel] Block at \(blockKey) | NO calorieData")
            }
        }
    }
    
    /// Create a block background view
    private func createBlockBackgroundView(for blockType: UnifiedTextContentStorage.BlockMetadata.BlockType) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false // Don't interfere with text editing
        updateBlockBackgroundAppearance(view, for: blockType)
        return view
    }
    
    /// Update block background view appearance
    private func updateBlockBackgroundAppearance(_ view: UIView, for blockType: UnifiedTextContentStorage.BlockMetadata.BlockType) {
        switch blockType {
        case .text:
            // Green tint for text blocks
            view.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.05)
        case .imageText:
            // Blue tint for image blocks
            view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.05)
        case .spacer:
            // Gray tint for spacer blocks (more visible for debug)
            view.backgroundColor = UIColor.systemGray.withAlphaComponent(0.25)
        }
    }
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
        let glyphRange = layoutManager.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)
        guard glyphRange.length > 0 else { return nil }
        let lastGlyphIndex = glyphRange.location + glyphRange.length - 1
        var lineRange = NSRange(location: 0, length: 0)
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: lastGlyphIndex, effectiveRange: &lineRange)
        // Convert from text container to view coordinates
        var rect = lineRect
        rect.origin.x += textContainerInset.left
        rect.origin.y += textContainerInset.top
        return rect
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
