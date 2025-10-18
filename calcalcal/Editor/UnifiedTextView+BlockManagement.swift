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
        if let affectedIndices = affectedBlockIndices, !affectedIndices.isEmpty {
            // Implement partial update for affected blocks only
            var didChangeAnyText = false
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
                // Replace the text in textStorage for this block only if content changed
                let safeLength = min(blockRange.length, max(0, textStorage.length - blockRange.location))
                let safeRange = NSRange(location: blockRange.location, length: max(0, safeLength))
                let existingString: String = safeRange.length > 0 && NSMaxRange(safeRange) <= textStorage.length
                    ? textStorage.attributedSubstring(from: safeRange).string
                    : ""
                if existingString != newAttributedText.string {
                    if blockRange.location + blockRange.length <= textStorage.length {
                        textStorage.replaceCharacters(in: blockRange, with: newAttributedText)
                    } else if blockRange.location <= textStorage.length {
                        // If the range is at the end, just append
                        let tailLength = max(0, textStorage.length - blockRange.location)
                        textStorage.replaceCharacters(in: NSRange(location: blockRange.location, length: tailLength), with: newAttributedText)
                    }
                    didChangeAnyText = true
                }
                // Update metadata for this block
                let newRange = NSRange(location: blockRange.location, length: newAttributedText.length)
                unifiedContentStorage.setBlockMetadata(metadata, for: newRange)
            }
            // Update visuals; if no text changed, still refresh lightweight visuals
            if didChangeAnyText {
                updateExclusionPaths()
                updateImageViews()
                updateBlockBackgroundViews()
            }
            scheduleThrottledLayoutUpdate()
            // Selection: only adjust when an explicit caret is provided
            if let caretToRestore = caret {
                let clamped = min(max(0, caretToRestore), textStorage.length)
                if self.selectedRange.location != clamped || self.selectedRange.length != 0 {
                    self.selectedRange = NSRange(location: clamped, length: 0)
                }
            }
            return
        }
        // Full rebuild path
        // Preserve selection before rebuilding to avoid jump to 0
        let previousSelection = self.selectedRange
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
        // After rendering, prefer throttled layout/display update
        scheduleThrottledLayoutUpdate()
        // Selection: restore to caret if provided, else restore previous selection clamped to bounds
        if let caretToRestore = caret {
            let clamped = min(max(0, caretToRestore), textStorage.length)
            if self.selectedRange.location != clamped || self.selectedRange.length != 0 {
                self.selectedRange = NSRange(location: clamped, length: 0)
            }
        } else {
            let clampedLocation = min(previousSelection.location, textStorage.length)
            if self.selectedRange.location != clampedLocation || self.selectedRange.length != previousSelection.length {
                self.selectedRange = NSRange(location: clampedLocation, length: 0)
            }
        }
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
                blockLength = (text + "\n").count
            case .image:
                // Assume image blocks are 2 chars (attachment + newline)
                blockLength = 2
            case .imageText(_, _, let text):
                blockLength = (text + "\n").count + 1 // image attachment + text + newline
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
    /// Updates calorie/nutrition metadata for a specific block without re-rendering text content
    func updateBlockMetadata(at index: Int, calorieData: String?, nutrition: NutritionData?) {
        guard let range = rangeForBlock(at: index) else { return }

        // Read existing metadata at the start of the block range
        guard var meta = unifiedContentStorage.blockMetadata(at: range.location) else { return }

        // Update fields
        meta.calorieData = calorieData
        meta.nutritionJSON = try? JSONEncoder().encode(nutrition)

        // Persist back for the same range
        unifiedContentStorage.setBlockMetadata(meta, for: range)

        // Refresh visuals that depend on metadata only
        updateBlockBackgroundViews()
        setNeedsDisplay()
    }
    
    /// Handle incoming metadata-only update notification
    @objc func handleApplyPerBlockMetadata(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        // Extract entryId and analyzedBlocks from notification
        guard let notificationEntryId = userInfo["entryId"] as? UUID else { return }
        guard let analyzedBlocks = userInfo["analyzedBlocks"] as? [AnalyzedBlock] else { return }
        
        // Filter by entryId to ensure we only process notifications for this editor instance
        guard self.entryId == notificationEntryId else { return }
        
        #if DEBUG
        print("📲 Applying metadata updates for \(analyzedBlocks.count) analyzed blocks")
        #endif
        
        applyNutritionMetadata(analyzedBlocks: analyzedBlocks)
    }
    
    /// Apply nutrition/calorie metadata to paragraphs without changing text content
    /// Matches analyzed blocks by exact text first, then falls back to positional matching
    /// Device text is always the source of truth; unmatched analyzed blocks are skipped
    func applyNutritionMetadata(analyzedBlocks: [AnalyzedBlock]) {
        guard !analyzedBlocks.isEmpty else { return }
        
        // Build list of non-empty textual paragraphs with their ranges and content
        var paragraphsList: [(range: NSRange, text: String, metadata: UnifiedTextContentStorage.BlockMetadata?)] = []
        let string = textStorage.string as NSString
        
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard paragraphRange.location < string.length else { return }
            let paragraphText = string.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraphText.isEmpty else { return }
            paragraphsList.append((range: paragraphRange, text: paragraphText, metadata: metadata))
        }
        
        // Track which analyzed blocks have been matched
        var matchedBlockIndices = Set<Int>()
        
        // PASS 1: Exact match by trimmed text equality (device-wins semantics)
        for (paraIdx, paragraph) in paragraphsList.enumerated() {
            for (blockIdx, block) in analyzedBlocks.enumerated() {
                guard !matchedBlockIndices.contains(blockIdx) else { continue }
                
                let deviceText = paragraph.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let serverText = block.content.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if deviceText == serverText {
                    // Match found: apply metadata to this paragraph
                    applyBlockMetadataToRange(paragraph.range, analyzedBlock: block)
                    matchedBlockIndices.insert(blockIdx)
                    
                    #if DEBUG
                    print("✅ Exact-matched paragraph at range \(paragraph.range) with analyzed block '\(serverText)'")
                    #endif
                    break
                }
            }
        }
        
        // PASS 2: Positional fallback for remaining unmatched blocks (best-effort)
        var nextParagraphIdx = 0
        for (blockIdx, block) in analyzedBlocks.enumerated() {
            guard !matchedBlockIndices.contains(blockIdx) else { continue }
            guard nextParagraphIdx < paragraphsList.count else { break }
            
            let paragraph = paragraphsList[nextParagraphIdx]
            applyBlockMetadataToRange(paragraph.range, analyzedBlock: block)
            matchedBlockIndices.insert(blockIdx)
            nextParagraphIdx += 1
            
            #if DEBUG
            print("⚠️ Positional-matched paragraph at range \(paragraph.range) (fallback)")
            #endif
        }
        
        // Refresh visuals to display updated metadata
        updateBlockBackgroundViews()
        setNeedsDisplay()
        
        // Reconstruct blocks from updated text storage and sync SwiftUI state
        updateBlocksFromTextStorage()
        
        #if DEBUG
        print("🎉 Metadata update complete: \(matchedBlockIndices.count)/\(analyzedBlocks.count) blocks applied")
        #endif
    }
    
    /// Apply an analyzed block's metadata to a specific paragraph range
    private func applyBlockMetadataToRange(_ paragraphRange: NSRange, analyzedBlock: AnalyzedBlock) {
        guard var metadata = unifiedContentStorage.blockMetadata(at: paragraphRange.location) else { return }
        
        // Update calorie data
        if let calories = analyzedBlock.calories {
            metadata.calorieData = String(calories)
        }
        
        // Build nutrition data from analyzed block fields
        if analyzedBlock.protein != nil || analyzedBlock.fat != nil || 
           analyzedBlock.carbs != nil || analyzedBlock.fiber != nil || 
           analyzedBlock.sugar != nil || analyzedBlock.sodium != nil ||
           analyzedBlock.calories != nil {
            
            let nutritionData = NutritionData(
                calories: analyzedBlock.calories,
                protein: analyzedBlock.protein,
                fat: analyzedBlock.fat,
                carbs: analyzedBlock.carbs,
                fiber: analyzedBlock.fiber,
                sugar: analyzedBlock.sugar,
                sodium: analyzedBlock.sodium,
                confidence: analyzedBlock.confidence
            )
            metadata.nutritionJSON = try? JSONEncoder().encode(nutritionData)
        }
        
        // Persist updated metadata back to storage
        unifiedContentStorage.setBlockMetadata(metadata, for: paragraphRange)
    }
    
    /// Reconstruct the blocks array from current text storage state
    /// This syncs the SwiftUI model with the latest metadata from text storage
    private func updateBlocksFromTextStorage() {
        let string = textStorage.string as NSString
        var newBlocks: [Block] = []
        
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard paragraphRange.location < string.length else { return }
            
            var paragraphText = string.substring(with: paragraphRange)
            if paragraphText.hasSuffix("\n") {
                paragraphText.removeLast()
            }
            
            let paragraphText_trimmed = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraphText_trimmed.isEmpty else { return }
            
            guard let metadata = metadata else {
                newBlocks.append(Block(type: .text(paragraphText), calorieData: nil))
                return
            }
            
            switch metadata.blockType {
            case .text:
                var nutrition: NutritionData? = nil
                if let data = metadata.nutritionJSON {
                    nutrition = try? JSONDecoder().decode(NutritionData.self, from: data)
                }
                newBlocks.append(Block(type: .text(paragraphText), calorieData: metadata.calorieData, nutrition: nutrition))
                
            case .imageText:
                if let imageRef = metadata.imageReference, let image = imageMap[imageRef], let imageData = image.pngData() {
                    var nutrition: NutritionData? = nil
                    if let d = metadata.nutritionJSON {
                        nutrition = try? JSONDecoder().decode(NutritionData.self, from: d)
                    }
                    newBlocks.append(Block(type: .imageText(imageData, imageRef, paragraphText), calorieData: metadata.calorieData, nutrition: nutrition))
                }
                
            case .spacer:
                newBlocks.append(Block(type: .spacer, calorieData: nil, nutrition: nil))
            }
        }
        
        // Update blocks array to keep SwiftUI state in sync
        if newBlocks != self.blocks {
            self.blocks = newBlocks
        }
    }
}
