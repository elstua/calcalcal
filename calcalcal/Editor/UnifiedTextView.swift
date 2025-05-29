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
        drawCalorieLabels(in: rect)
    }
    
    private func drawBlockBackgrounds(in rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Save context state
        context.saveGState()
        
        // Draw backgrounds for each block
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard metadata != nil else { return }
            
            // Get the frame for this paragraph using layoutManager
            let glyphRange = self.layoutManager.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)
            let boundingRect = self.layoutManager.boundingRect(forGlyphRange: glyphRange, in: self.textContainer)
            
            // Adjust frame for container insets
            var blockFrame = boundingRect
            blockFrame.origin.x += self.textContainerInset.left
            blockFrame.origin.y += self.textContainerInset.top
            blockFrame.size.width = self.bounds.width - self.textContainerInset.left - self.textContainerInset.right
            
            // Add spacing below the block
            let spacing = self.unifiedLayoutManager.spacingForBlock(with: metadata)
            
            // Draw subtle background
            context.setFillColor(UIColor.systemGray6.cgColor)
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