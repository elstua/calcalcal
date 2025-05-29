import UIKit

/// Custom text view for unified block-based editing
class UnifiedTextView: UITextView {
    
    // MARK: - Components
    
    private(set) var unifiedContentStorage: UnifiedTextContentStorage!
    private(set) var unifiedLayoutManager: UnifiedTextLayoutManager!
    
    // MARK: - Configuration
    
    /// Default block spacing for new blocks
    var defaultBlockSpacing: CGFloat = 16.0 {
        didSet {
            unifiedLayoutManager?.defaultBlockSpacing = defaultBlockSpacing
            setNeedsDisplay()
        }
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupComponents()
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupComponents()
        setupView()
    }
    
    private func setupComponents() {
        // Create our custom components
        unifiedContentStorage = UnifiedTextContentStorage()
        unifiedLayoutManager = UnifiedTextLayoutManager()
        
        // Store reference to our text storage
        unifiedContentStorage.textStorage = self.textStorage
    }
    
    private func setupView() {
        // Configure text container
        textContainer.lineFragmentPadding = 16
        textContainer.widthTracksTextView = true
        
        // Configure appearance
        backgroundColor = .systemBackground
        font = UIFont.systemFont(ofSize: 16)
        textColor = .label
        
        // Enable editing
        isEditable = true
        isSelectable = true
        
        // Add padding
        textContainerInset = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
        
        // Set up delegate
        delegate = self
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update exclusion paths when layout changes
        updateExclusionPaths()
    }
    
    // MARK: - Block Management
    
    /// Add a new text block with the given content
    func addTextBlock(_ text: String, calorieData: String? = nil) {
        let blockText = text.isEmpty ? "\n" : text + "\n"
        
        // Insert at the end
        let insertionPoint = textStorage.length
        textStorage.insert(NSAttributedString(string: blockText), at: insertionPoint)
        
        // Set block metadata
        let blockRange = NSRange(location: insertionPoint, length: blockText.count)
        let metadata = UnifiedTextContentStorage.BlockMetadata(
            blockType: .text,
            blockSpacing: defaultBlockSpacing,
            imageReference: nil,
            calorieData: calorieData
        )
        
        unifiedContentStorage.setBlockMetadata(metadata, for: blockRange)
    }
    
    /// Add a new image-text block with placeholder image and text
    func addImageBlock(_ text: String = "This is an image block with text flowing alongside. The image takes up 30% of the width while the text uses the remaining 70%.", imageReference: UUID? = nil, calorieData: String? = nil) {
        // Ensure we add double newline if there's existing content
        let prefix = textStorage.length > 0 ? "\n\n" : ""
        let blockText = prefix + (text.isEmpty ? "\n" : text + "\n")
        
        // Insert at the end
        let insertionPoint = textStorage.length
        textStorage.insert(NSAttributedString(string: blockText), at: insertionPoint)
        
        // Set block metadata as image-text type
        // Skip the prefix newlines when setting metadata
        let metadataStart = insertionPoint + prefix.count
        let metadataLength = blockText.count - prefix.count
        let blockRange = NSRange(location: metadataStart, length: metadataLength)
        
        let metadata = UnifiedTextContentStorage.BlockMetadata(
            blockType: .imageText,
            blockSpacing: defaultBlockSpacing,
            imageReference: imageReference ?? UUID(),
            calorieData: calorieData
        )
        
        unifiedContentStorage.setBlockMetadata(metadata, for: blockRange)
        
        // Update paragraph detection
        updateParagraphBlocks()
        
        // Update exclusion paths for the new block
        updateExclusionPaths()
    }
    
    /// Update exclusion paths for image-text blocks
    private func updateExclusionPaths() {
        var exclusionPaths: [UIBezierPath] = []
        
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard let metadata = metadata,
                  metadata.blockType == .imageText else { return }
            
            // Get the frame for this paragraph
            let glyphRange = self.layoutManager.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)
            let boundingRect = self.layoutManager.boundingRect(forGlyphRange: glyphRange, in: self.textContainer)
            
            // Calculate image area (30% of text container width)
            let containerWidth = self.textContainer.size.width - self.textContainer.lineFragmentPadding * 2
            let imageWidth = containerWidth * 0.3
            let imageHeight = max(80, boundingRect.height) // Minimum 80pt height
            
            // Create exclusion path relative to text container coordinates
            // Note: exclusion paths are relative to the text container, not the view
            let imageFrame = CGRect(
                x: 0, // Left edge of text container
                y: boundingRect.origin.y,
                width: imageWidth,
                height: imageHeight
            )
            
            let path = UIBezierPath(rect: imageFrame)
            exclusionPaths.append(path)
        }
        
        // Apply exclusion paths to text container
        textContainer.exclusionPaths = exclusionPaths
        
        // Force layout update
        layoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textStorage.length), actualCharacterRange: nil)
        setNeedsDisplay()
    }
    
    /// Update paragraph detection after text changes
    private func updateParagraphBlocks() {
        // Clear existing metadata
        let fullRange = NSRange(location: 0, length: textStorage.length)
        
        // Re-detect paragraphs and assign default metadata
        unifiedContentStorage.enumerateParagraphs(in: fullRange) { paragraphRange, existingMetadata in
            if existingMetadata == nil {
                // Assign default metadata to new paragraphs
                let metadata = UnifiedTextContentStorage.BlockMetadata(
                    blockType: .text,
                    blockSpacing: self.defaultBlockSpacing,
                    imageReference: nil,
                    calorieData: nil
                )
                self.unifiedContentStorage.setBlockMetadata(metadata, for: paragraphRange)
            }
        }
        
        // Trigger layout update
        setNeedsDisplay()
    }
    
    // MARK: - Calorie Management
    
    /// Update calorie data for the block at the given location
    func updateCalorieData(_ calories: String, at location: Int) {
        guard let metadata = unifiedContentStorage.blockMetadata(at: location) else { return }
        
        // Find the paragraph range
        var paragraphRange = NSRange(location: 0, length: 0)
        unifiedContentStorage.enumerateParagraphs { range, blockMetadata in
            if NSLocationInRange(location, range) {
                paragraphRange = range
                return
            }
        }
        
        // Update metadata
        var updatedMetadata = metadata
        updatedMetadata.calorieData = calories
        unifiedContentStorage.setBlockMetadata(updatedMetadata, for: paragraphRange)
        
        // Trigger redraw
        setNeedsDisplay()
    }
    
    // MARK: - Drawing
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        // Additional drawing for block backgrounds, borders, etc.
        drawBlockBackgrounds(in: rect)
        drawImagePlaceholders(in: rect)
        drawCalorieLabels(in: rect)
    }
    
    private func drawBlockBackgrounds(in rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Save context state
        context.saveGState()
        
        // Draw backgrounds for each block
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard let metadata = metadata else { return }
            
            // Get the frame for this paragraph using layoutManager
            let glyphRange = self.layoutManager.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)
            let boundingRect = self.layoutManager.boundingRect(forGlyphRange: glyphRange, in: self.textContainer)
            
            // Adjust frame for container insets
            var blockFrame = boundingRect
            blockFrame.origin.x += self.textContainerInset.left
            blockFrame.origin.y += self.textContainerInset.top
            blockFrame.size.width = self.bounds.width - self.textContainerInset.left - self.textContainerInset.right
            
            // For image blocks, ensure minimum height
            if metadata.blockType == .imageText {
                blockFrame.size.height = max(80, blockFrame.height)
            }
            
            // Add spacing below the block
            let spacing = self.unifiedLayoutManager.spacingForBlock(with: metadata)
            
            // Draw debug background based on block type
            switch metadata.blockType {
            case .text:
                // Green tint for text blocks
                context.setFillColor(UIColor.systemGreen.withAlphaComponent(0.1).cgColor)
            case .imageText:
                // Blue tint for image blocks
                context.setFillColor(UIColor.systemBlue.withAlphaComponent(0.1).cgColor)
            }
            
            context.fill(blockFrame.insetBy(dx: 0, dy: 2))
            
            // Draw separator line after block
            context.setStrokeColor(UIColor.separator.cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: blockFrame.minX + 16, y: blockFrame.maxY + spacing/2))
            context.addLine(to: CGPoint(x: blockFrame.maxX - 16, y: blockFrame.maxY + spacing/2))
            context.strokePath()
        }
        
        // Restore context state
        context.restoreGState()
    }
    
    private func drawImagePlaceholders(in rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Save context state
        context.saveGState()
        
        // Draw image placeholders for image-text blocks
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard let metadata = metadata,
                  metadata.blockType == .imageText else { return }
            
            // Get the frame for this paragraph
            let glyphRange = self.layoutManager.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)
            let boundingRect = self.layoutManager.boundingRect(forGlyphRange: glyphRange, in: self.textContainer)
            
            // Calculate image area (30% of text container width)
            let containerWidth = self.textContainer.size.width - self.textContainer.lineFragmentPadding * 2
            let imageWidth = containerWidth * 0.3
            let imageHeight = max(80, boundingRect.height) // Minimum 80pt height
            
            // Create image frame aligned with text container
            let imageFrame = CGRect(
                x: self.textContainerInset.left + self.textContainer.lineFragmentPadding,
                y: boundingRect.origin.y + self.textContainerInset.top,
                width: imageWidth - 8, // Add some padding
                height: imageHeight
            )
            
            // Draw grey placeholder rectangle
            context.setFillColor(UIColor.systemGray4.cgColor)
            context.fill(imageFrame)
            
            // Draw a subtle border
            context.setStrokeColor(UIColor.systemGray3.cgColor)
            context.setLineWidth(1.0)
            context.stroke(imageFrame)
            
            // Draw an image icon in the center
            let iconSize: CGFloat = 24
            let iconRect = CGRect(
                x: imageFrame.midX - iconSize/2,
                y: imageFrame.midY - iconSize/2,
                width: iconSize,
                height: iconSize
            )
            
            // Draw a simple image icon (square with mountain shape)
            context.setStrokeColor(UIColor.systemGray2.cgColor)
            context.setLineWidth(2.0)
            
            // Draw the icon frame
            context.stroke(iconRect)
            
            // Draw mountain shape inside
            context.move(to: CGPoint(x: iconRect.minX + 4, y: iconRect.maxY - 4))
            context.addLine(to: CGPoint(x: iconRect.minX + iconRect.width * 0.3, y: iconRect.minY + iconRect.height * 0.4))
            context.addLine(to: CGPoint(x: iconRect.minX + iconRect.width * 0.6, y: iconRect.minY + iconRect.height * 0.6))
            context.addLine(to: CGPoint(x: iconRect.maxX - 4, y: iconRect.maxY - 4))
            context.strokePath()
        }
        
        // Restore context state
        context.restoreGState()
    }
    
    private func drawCalorieLabels(in rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Draw calorie labels for blocks that have them
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard let metadata = metadata,
                  let calories = metadata.calorieData else { return }
            
            // Get the frame for this paragraph
            let glyphRange = self.layoutManager.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)
            let boundingRect = self.layoutManager.boundingRect(forGlyphRange: glyphRange, in: self.textContainer)
            
            // Adjust frame for container insets
            var blockFrame = boundingRect
            blockFrame.origin.x += self.textContainerInset.left
            blockFrame.origin.y += self.textContainerInset.top
            blockFrame.size.width = self.bounds.width - self.textContainerInset.left - self.textContainerInset.right
            
            // Draw calorie label
            self.unifiedLayoutManager.drawCalorieLabel(calories, in: blockFrame, context: context)
        }
    }
}

// MARK: - UITextViewDelegate

extension UnifiedTextView: UITextViewDelegate {
    
    func textViewDidChange(_ textView: UITextView) {
        // Update paragraph blocks after text changes
        updateParagraphBlocks()
        
        // Update exclusion paths for image-text blocks
        updateExclusionPaths()
        
        // Update block ranges after editing
        if let selectedRange = textView.selectedTextRange {
            let location = textView.offset(from: textView.beginningOfDocument, to: selectedRange.start)
            // We'll handle this more intelligently in the future
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Allow all text changes for now
        return true
    }
} 