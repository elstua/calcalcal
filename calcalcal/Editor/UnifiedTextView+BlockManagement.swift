import UIKit

// MARK: - Block Management Extension

// MARK: - Block Model Integration

extension UnifiedTextView {
    /// The array of blocks representing the editor's content
    var blocks: [Block] {
        get {
            if let value = objc_getAssociatedObject(self, &AssociatedKeys.blocks) as? [Block] {
                return value
            }
            let initial: [Block] = []
            objc_setAssociatedObject(self, &AssociatedKeys.blocks, initial, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return initial
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.blocks, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Render the blocks array into the text storage and metadata
    func renderBlocks(restoreCaretTo caret: Int? = nil, affectedBlockIndices: [Int]? = nil) {
        // Enter programmatic update to suppress delegate-driven loops
        if isProgrammaticUpdate { return }
        isProgrammaticUpdate = true
        defer { isProgrammaticUpdate = false }
        // Capture caret before making any mutations so we can restore reliably
        let caretToRestoreGlobal = caret ?? self.selectedRange.location
        if let affectedIndices = affectedBlockIndices, !affectedIndices.isEmpty {
            // Implement partial update for affected blocks only
            let caretToRestore = caretToRestoreGlobal
            var caretRestored = false
            for index in affectedIndices {
                guard let blockRange = rangeForBlock(at: index), index < blocks.count else { continue }
                let block = blocks[index]
                let newAttributedText: NSAttributedString
                let metadata: UnifiedTextContentStorage.BlockMetadata
                switch block.type {
                case .text(let text):
                    let blockText = text + "\n"
                    let attributedText = NSMutableAttributedString(string: blockText)
                    attributedText.addAttribute(.font, value: self.font ?? UIFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: blockText.count))
                    attributedText.addAttribute(.foregroundColor, value: self.textColor ?? UIColor.label, range: NSRange(location: 0, length: blockText.count))
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.paragraphSpacing = 0
                    attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: blockText.count))
                    newAttributedText = attributedText
                    var meta = UnifiedTextContentStorage.BlockMetadata(
                        blockType: .text,
                        blockSpacing: defaultBlockSpacing,
                        imageReference: nil,
                        calorieData: block.calorieData,
                        nutritionJSON: try? JSONEncoder().encode(block.nutrition)
                    )
                    metadata = meta
                case .image(let imageData, let imageRef):
                    let (attributedText, meta) = ImageTextBlockLayout.attributedStringForImageBlock(
                        imageData: imageData,
                        imageRef: imageRef,
                        font: self.font,
                        textColor: self.textColor,
                        defaultBlockSpacing: defaultBlockSpacing,
                        calorieData: block.calorieData
                    )
                    newAttributedText = attributedText
                    var meta2 = meta
                    meta2.nutritionJSON = try? JSONEncoder().encode(block.nutrition)
                    metadata = meta2
                case .imageText(_, let imageRef, let text):
                    let (attributedText, meta) = ImageTextBlockLayout.attributedStringForImageTextBlock(
                        text: text,
                        imageRef: imageRef,
                        font: self.font,
                        textColor: self.textColor,
                        defaultBlockSpacing: defaultBlockSpacing,
                        calorieData: block.calorieData
                    )
                    newAttributedText = attributedText
                    var meta3 = meta
                    meta3.nutritionJSON = try? JSONEncoder().encode(block.nutrition)
                    metadata = meta3
                case .spacer:
                    let blockText = "\n"
                    let attributedText = NSMutableAttributedString(string: blockText)
                    attributedText.addAttribute(.font, value: self.font ?? UIFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: blockText.count))
                    attributedText.addAttribute(.foregroundColor, value: self.textColor ?? UIColor.label, range: NSRange(location: 0, length: blockText.count))
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.paragraphSpacing = 0
                    attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: blockText.count))
                    newAttributedText = attributedText
                    let metadataTemp = UnifiedTextContentStorage.BlockMetadata(
                        blockType: .spacer,
                        blockSpacing: defaultSpacerHeight,
                        imageReference: nil,
                        calorieData: nil,
                        nutritionJSON: nil
                    )
                    metadata = metadataTemp
                }
                // Replace the text in textStorage for this block
                if blockRange.location + blockRange.length <= textStorage.length {
                    textStorage.replaceCharacters(in: blockRange, with: newAttributedText)
                } else if blockRange.location <= textStorage.length {
                    // If the range is at the end, just append
                    textStorage.replaceCharacters(in: NSRange(location: blockRange.location, length: textStorage.length - blockRange.location), with: newAttributedText)
                }
                // Update metadata for this block
                let newRange = NSRange(location: blockRange.location, length: newAttributedText.length)
                unifiedContentStorage.setBlockMetadata(metadata, for: newRange)

                // Improved caret restoration: if caret was inside this block, restore to same offset
                if !caretRestored && caretToRestore >= blockRange.location && caretToRestore <= blockRange.location + newAttributedText.length {
                    // Restore using UTF-16 aware indices
                    let offsetInBlock = max(0, min(caretToRestore - blockRange.location, newAttributedText.length))
                    let newCaret = min(blockRange.location + offsetInBlock, textStorage.length)
                    self.selectedRange = NSRange(location: newCaret, length: 0)
                    caretRestored = true
                }
            }
            // Always update exclusion paths, image views, and block backgrounds after partial update
            updateExclusionPaths()
            updateImageViews()
            updateBlockBackgroundViews()
            setNeedsLayout()
            setNeedsDisplay()
            // If caret wasn't restored in a block, restore to previous logic
            if !caretRestored {
                let newCaret = min(caretToRestore, textStorage.length)
                self.selectedRange = NSRange(location: newCaret, length: 0)
            }
            return
        }
        // Clear the text storage (full rebuild)
        textStorage.setAttributedString(NSAttributedString(string: ""))
        
        // Track the current insertion point
        var currentLocation = 0
        
        for block in blocks {
            switch block.type {
            case .text(let text):
                let blockText = text + "\n"
                let attributedText = NSMutableAttributedString(string: blockText)
                attributedText.addAttribute(.font, value: self.font ?? UIFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: blockText.count))
                attributedText.addAttribute(.foregroundColor, value: self.textColor ?? UIColor.label, range: NSRange(location: 0, length: blockText.count))
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.paragraphSpacing = 0
                attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: blockText.count))
                textStorage.append(attributedText)
                // Assign metadata
                let blockRange = NSRange(location: currentLocation, length: blockText.count)
                var metadata = UnifiedTextContentStorage.BlockMetadata(
                    blockType: .text,
                    blockSpacing: defaultBlockSpacing,
                    imageReference: nil,
                    calorieData: block.calorieData,
                    nutritionJSON: try? JSONEncoder().encode(block.nutrition)
                )
                unifiedContentStorage.setBlockMetadata(metadata, for: blockRange)
                currentLocation += blockText.count
            case .image(let imageData, let imageRef):
                let (attributedText, metadata) = ImageTextBlockLayout.attributedStringForImageBlock(
                    imageData: imageData,
                    imageRef: imageRef,
                    font: self.font,
                    textColor: self.textColor,
                    defaultBlockSpacing: defaultBlockSpacing,
                    calorieData: block.calorieData
                )
                textStorage.append(attributedText)
                let blockRange = NSRange(location: currentLocation, length: attributedText.length)
                var meta2 = metadata
                meta2.nutritionJSON = try? JSONEncoder().encode(block.nutrition)
                unifiedContentStorage.setBlockMetadata(meta2, for: blockRange)
                currentLocation += attributedText.length
            case .imageText(_, let imageRef, let text):
                let (attributedText, metadata) = ImageTextBlockLayout.attributedStringForImageTextBlock(
                    text: text,
                    imageRef: imageRef,
                    font: self.font,
                    textColor: self.textColor,
                    defaultBlockSpacing: defaultBlockSpacing,
                    calorieData: block.calorieData
                )
                textStorage.append(attributedText)
                let blockRange = NSRange(location: currentLocation, length: attributedText.length)
                var meta3 = metadata
                meta3.nutritionJSON = try? JSONEncoder().encode(block.nutrition)
                unifiedContentStorage.setBlockMetadata(meta3, for: blockRange)
                currentLocation += attributedText.length
            case .spacer:
                let blockText = "\n"
                let attributedText = NSMutableAttributedString(string: blockText)
                attributedText.addAttribute(.font, value: self.font ?? UIFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: blockText.count))
                attributedText.addAttribute(.foregroundColor, value: self.textColor ?? UIColor.label, range: NSRange(location: 0, length: blockText.count))
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.paragraphSpacing = 0
                attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: blockText.count))
                textStorage.append(attributedText)
                // Assign metadata
                let blockRange = NSRange(location: currentLocation, length: blockText.count)
                let metadata = UnifiedTextContentStorage.BlockMetadata(
                    blockType: .spacer,
                    blockSpacing: defaultSpacerHeight,
                    imageReference: nil,
                    calorieData: nil,
                    nutritionJSON: nil
                )
                unifiedContentStorage.setBlockMetadata(metadata, for: blockRange)
                currentLocation += blockText.count
            }
        }
        // After rendering, force layout and display update
        setNeedsLayout()
        setNeedsDisplay()
        // Restore caret position if possible
        let newCaret = min(caretToRestoreGlobal, textStorage.length)
        self.selectedRange = NSRange(location: newCaret, length: 0)
    }

    /// Add a new text block to the model and re-render
    func addTextBlockModel(_ text: String, calorieData: String? = nil) {
        var currentBlocks = self.blocks
        let block = Block(type: .text(text), calorieData: calorieData)
        currentBlocks.append(block)
        self.blocks = currentBlocks
        renderBlocks()
    }

    /// Add a new image block to the model and re-render
    func addImageBlockModel(_ image: UIImage, text: String = "Enter description...", calorieData: String? = nil) {
        var currentBlocks = self.blocks
        if let block = ImageTextBlockLayout.createImageTextBlock(image: image, text: text, calorieData: calorieData) {
            currentBlocks.append(block)
            self.blocks = currentBlocks
            renderBlocks()
        }
    }

    /// Add a new spacer block to the model and re-render
    func addSpacerBlockModel() {
        var currentBlocks = self.blocks
        let block = Block(type: .spacer, calorieData: nil)
        currentBlocks.append(block)
        self.blocks = currentBlocks
        renderBlocks()
    }

    /// Helper: Get the NSRange in textStorage for a given block index
    internal func rangeForBlock(at index: Int) -> NSRange? {
        guard index >= 0 && index < blocks.count else { return nil }
        let string = textStorage.string as NSString
        var location = 0
        for i in 0..<blocks.count {
            let block = blocks[i]
            let blockLength: Int
            switch block.type {
            case .text(let text):
                // Use NSString length to match UTF-16 storage length
                blockLength = (text as NSString).length + 1 // +1 for newline
            case .image:
                // Assume image blocks are 2 chars (attachment + newline)
                blockLength = 2
            case .imageText(_, _, let text):
                // 1 for attachment + text length (UTF-16) + 1 for newline
                blockLength = 1 + (text as NSString).length + 1
            case .spacer:
                blockLength = 1 // newline
            }
            if i == index {
                // Clamp range to string length
                let safeLength = max(0, min(blockLength, string.length - location))
                return NSRange(location: location, length: safeLength)
            }
            location += blockLength
        }
        return nil
    }
}

private struct AssociatedKeys {
    static var blocks = "UnifiedTextView_blocks"
} 

// MARK: - Metadata-only updates
extension UnifiedTextView {
    /// Update only calorie/nutrition metadata for a given block index, without touching text content
    func updateBlockMetadata(at index: Int, calorieData: String?, nutrition: NutritionData?) {
        if isProgrammaticUpdate { return }
        isProgrammaticUpdate = true
        defer { isProgrammaticUpdate = false }
        guard let range = rangeForBlock(at: index) else { return }
        // Get existing metadata if present to preserve blockType, spacing and imageReference
        var existing = unifiedContentStorage.blockMetadata(for: range)
        // If no metadata yet (e.g., freshly typed), derive a minimal one from current block type
        if existing == nil, index < blocks.count {
            let block = blocks[index]
            switch block.type {
            case .text:
                existing = UnifiedTextContentStorage.BlockMetadata(
                    blockType: .text,
                    blockSpacing: defaultBlockSpacing,
                    imageReference: nil,
                    calorieData: nil,
                    nutritionJSON: nil
                )
            case .image(let data, let imageRef):
                _ = data // unused here, but keep pattern exhaustive
                existing = UnifiedTextContentStorage.BlockMetadata(
                    blockType: .imageText,
                    blockSpacing: defaultBlockSpacing * 2,
                    imageReference: imageRef,
                    calorieData: nil,
                    nutritionJSON: nil
                )
            case .imageText(_, let imageRef, _):
                existing = UnifiedTextContentStorage.BlockMetadata(
                    blockType: .imageText,
                    blockSpacing: defaultBlockSpacing * 2,
                    imageReference: imageRef,
                    calorieData: nil,
                    nutritionJSON: nil
                )
            case .spacer:
                existing = UnifiedTextContentStorage.BlockMetadata(
                    blockType: .spacer,
                    blockSpacing: defaultSpacerHeight,
                    imageReference: nil,
                    calorieData: nil,
                    nutritionJSON: nil
                )
            }
        }
        guard var meta = existing else { return }
        meta.calorieData = calorieData
        meta.nutritionJSON = try? JSONEncoder().encode(nutrition)
        unifiedContentStorage.setBlockMetadata(meta, for: range)
        // Refresh visuals for calorie label/background only
        updateBlockBackgroundViews()
        setNeedsDisplay()
    }
}
