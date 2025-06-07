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
        
        // Only process paragraphs that have actual content
        let string = textStorage.string as NSString
        guard string.length > 0 else {
            // Clear all exclusion paths if no content
            textContainer.exclusionPaths = []
            return
        }
        
        print("🎯 Updating exclusion paths for image blocks")
        
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            let blockTypeDesc = metadata?.blockType == .imageText ? "imageText" : (metadata?.blockType == .text ? "text" : "none")
            print("[ExclusionPath] Checking paragraph at range \(paragraphRange), blockType: \(blockTypeDesc)")
            guard let metadata = metadata,
                  metadata.blockType == .imageText,
                  paragraphRange.location < string.length else {
                print("[ExclusionPath] Skipping paragraph at range \(paragraphRange), blockType: \(blockTypeDesc)")
                return
            }
            // Verify the paragraph actually contains text
            let paragraphText = string.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraphText.isEmpty else {
                print("[ExclusionPath] Skipping empty imageText block at range \(paragraphRange)")
                return
            }
            // Get the frame for this paragraph using compatibility method
            let boundingRect = self.boundingRect(for: paragraphRange)
            // Calculate image area (30% of text container width)
            let containerWidth = self.textContainer.size.width - self.textContainer.lineFragmentPadding * 2
            let imageWidth = containerWidth * 0.3
            let imageHeight = max(100, boundingRect.height) // Minimum 100pt height for better spacing
            // Create exclusion path relative to text container coordinates
            let imageFrame = CGRect(
                x: 0, // Left edge of text container
                y: boundingRect.origin.y,
                width: imageWidth,
                height: imageHeight
            )
            let path = UIBezierPath(rect: imageFrame)
            exclusionPaths.append(path)
            print("[ExclusionPath] Added exclusion path for imageText block at range \(paragraphRange): \(imageFrame)")
        }
        
        // Apply exclusion paths to text container
        // Add a right-side exclusion path for the calorie label area (applies to all blocks)
        let totalWidth = self.textContainer.size.width
        let calorieAreaWidth = totalWidth * 0.15
        let exclusionRect = CGRect(
            x: totalWidth - calorieAreaWidth,
            y: 0,
            width: calorieAreaWidth,
            height: self.bounds.height
        )
        let calorieExclusionPath = UIBezierPath(rect: exclusionRect)
        exclusionPaths.append(calorieExclusionPath)
        textContainer.exclusionPaths = exclusionPaths
        print("✅ Applied \(exclusionPaths.count) exclusion paths to text container")
        
        // Force IMMEDIATE and thorough layout invalidation
        // This is crucial to ensure text reflows correctly after exclusion paths are set
        layoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textStorage.length), actualCharacterRange: nil)
        layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textStorage.length))
        
        // Force the text container to recalculate all line fragments
        layoutManager.ensureLayout(forCharacterRange: NSRange(location: 0, length: textStorage.length))
        
        // Force view updates
        setNeedsLayout()
        setNeedsDisplay()
    }
    
    // MARK: - Image View Management
    
    /// Update image views for image-text blocks
    internal func updateImageViews() {
        // Remove image views that no longer exist
        var currentImageRefs = Set<UUID>()
        
        // Only process paragraphs that have actual content
        let string = textStorage.string as NSString
        guard string.length > 0 else {
            // Remove all image views if no content
            for (_, imageView) in imageViews {
                imageView.removeFromSuperview()
            }
            imageViews.removeAll()
            return
        }
        
        // First, collect all current image references from valid paragraphs
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard let metadata = metadata,
                  metadata.blockType == .imageText,
                  let imageRef = metadata.imageReference,
                  paragraphRange.location < string.length else { return }
            
            // Verify the paragraph actually contains text
            let paragraphText = string.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraphText.isEmpty else { return }
            
            currentImageRefs.insert(imageRef)
        }
        
        // Remove views for images that no longer exist
        for (imageRef, imageView) in imageViews {
            if !currentImageRefs.contains(imageRef) {
                imageView.removeFromSuperview()
                imageViews.removeValue(forKey: imageRef)
            }
        }
        
        // Update positions for existing images and create new ones
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard let metadata = metadata,
                  metadata.blockType == .imageText,
                  let imageRef = metadata.imageReference,
                  paragraphRange.location < string.length else { return }
            
            // Verify the paragraph actually contains text
            let paragraphText = string.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraphText.isEmpty else { return }
            
            // Get the frame for this paragraph using compatibility method
            let boundingRect = self.boundingRect(for: paragraphRange)
            
            // Calculate image area (30% of text container width)
            let containerWidth = self.textContainer.size.width - self.textContainer.lineFragmentPadding * 2
            let imageWidth = containerWidth * 0.3
            let imageHeight = max(100, boundingRect.height) // Minimum 100pt height matching exclusion path
            
            // Create image frame using text container coordinates
            var imageFrame = CGRect(
                x: 0, // Left edge of text container (matches exclusion path)
                y: boundingRect.origin.y,
                width: imageWidth,
                height: imageHeight
            )
            
            // Convert from text container coordinates to view coordinates
            imageFrame.origin.x += self.textContainerInset.left + self.textContainer.lineFragmentPadding
            imageFrame.origin.y += self.textContainerInset.top
            imageFrame.size.width -= 8 // Add some padding
            
            // Get or create image view
            let imageView: UIView
            if let existingView = imageViews[imageRef] {
                imageView = existingView
            } else {
                imageView = createImagePlaceholderView()
                imageViews[imageRef] = imageView
                addSubview(imageView)
            }
            
            // Update frame
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
            
            // Verify the paragraph actually contains text
            let paragraphText = string.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraphText.isEmpty else { return }
            
            let blockKey = "\(paragraphRange.location):\(paragraphRange.length)"
            
            // Get the frame for this paragraph using compatibility method
            let boundingRect = self.boundingRect(for: paragraphRange)
            
            // Convert from text container coordinates to view coordinates
            var blockFrame = boundingRect
            blockFrame.origin.x += self.textContainerInset.left
            blockFrame.origin.y += self.textContainerInset.top
            
            // Calculate block width based on type
            let totalBlockWidth = self.bounds.width - self.textContainerInset.left - self.textContainerInset.right
            let textAreaWidth = totalBlockWidth * 0.85
            if metadata.blockType == .imageText {
                // For image blocks, background should cover the left 85% (text area)
                blockFrame.size.height = max(100, blockFrame.height)
                blockFrame.size.width = textAreaWidth
                blockFrame.origin.x = self.textContainerInset.left
            } else {
                // For text blocks, background should also cover only the left 85%
                blockFrame.size.width = textAreaWidth
            }
            
            // Inset the frame slightly for visual appeal
            blockFrame = blockFrame.insetBy(dx: 0, dy: 2)
            
            // Get or create block background view
            let backgroundView: UIView
            if let existingView = blockBackgroundViews[blockKey] {
                backgroundView = existingView
            } else {
                backgroundView = createBlockBackgroundView(for: metadata.blockType)
                blockBackgroundViews[blockKey] = backgroundView
                // Insert at the back so it doesn't interfere with text selection
                insertSubview(backgroundView, at: 0)
            }
            
            // Update frame and appearance
            backgroundView.frame = blockFrame
            updateBlockBackgroundAppearance(backgroundView, for: metadata.blockType)
            
            // Create separator line view if needed
            let separatorKey = blockKey + "_separator"
            let spacing = metadata.blockSpacing
            let separatorY = blockFrame.maxY + spacing/2
            let separatorFrame = CGRect(
                x: self.textContainerInset.left + 16,
                y: separatorY,
                width: self.bounds.width - self.textContainerInset.left - self.textContainerInset.right - 32,
                height: 0.5
            )
            
            // Handle separator view
            if let separatorView = blockBackgroundViews[separatorKey] {
                separatorView.frame = separatorFrame
            } else {
                let separatorView = UIView()
                separatorView.backgroundColor = UIColor.separator
                separatorView.frame = separatorFrame
                blockBackgroundViews[separatorKey] = separatorView
                insertSubview(separatorView, at: 0)
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
        }
    }
} 
