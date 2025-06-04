import UIKit

// MARK: - Block Management Extension

extension UnifiedTextView {
    
    // MARK: - Block Analysis
    
    /// Get a comprehensive count and analysis of all blocks in the editor
    func getBlockAnalysis() -> (totalBlocks: Int, textBlocks: Int, imageBlocks: Int, details: [String]) {
        var totalBlocks = 0
        var textBlocks = 0
        var imageBlocks = 0
        var details: [String] = []
        
        let string = textStorage.string as NSString
        guard string.length > 0 else {
            return (0, 0, 0, ["No content in editor"])
        }
        
        // Enumerate all paragraphs to understand what's happening
        string.enumerateSubstrings(in: NSRange(location: 0, length: string.length),
                                  options: [.byParagraphs, .localized]) { (substring, range, enclosingRange, _) in
            
            let paragraphText = substring?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let isEmpty = paragraphText.isEmpty
            let hasMetadata = self.unifiedContentStorage.blockMetadata(at: range.location) != nil
            
            if !isEmpty {
                totalBlocks += 1
                
                if let metadata = self.unifiedContentStorage.blockMetadata(at: range.location) {
                    switch metadata.blockType {
                    case .text:
                        textBlocks += 1
                        details.append("✅ Text Block #\(totalBlocks) at \(range.location)-\(range.location + range.length): '\(paragraphText.prefix(30))...'")
                    case .imageText:
                        imageBlocks += 1
                        details.append("🖼️ Image Block #\(totalBlocks) at \(range.location)-\(range.location + range.length): '\(paragraphText.prefix(30))...'")
                    }
                } else {
                    details.append("❌ Paragraph #\(totalBlocks) at \(range.location)-\(range.location + range.length): NO METADATA - '\(paragraphText.prefix(30))...'")
                }
            } else {
                details.append("⚪ Empty paragraph at \(range.location)-\(range.location + range.length)")
            }
        }
        
        return (totalBlocks, textBlocks, imageBlocks, details)
    }
    
    /// Print detailed block analysis to console for debugging
    func printBlockAnalysis() {
        let analysis = getBlockAnalysis()
        
        print("\n=== BLOCK ANALYSIS ===")
        print("Total Blocks: \(analysis.totalBlocks)")
        print("Text Blocks: \(analysis.textBlocks)")
        print("Image Blocks: \(analysis.imageBlocks)")
        print("Details:")
        for detail in analysis.details {
            print("  \(detail)")
        }
        
        // Also check metadata enumeration with frame information
        print("\nBlock Frame Analysis:")
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            let string = self.textStorage.string as NSString
            if paragraphRange.location < string.length {
                let text = string.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    // Calculate the frame for debugging
                    let boundingRect = self.boundingRect(for: paragraphRange)
                    let lineCount = text.components(separatedBy: .newlines).count
                    
                    print("  📐 Block at \(paragraphRange.location)-\(paragraphRange.location + paragraphRange.length):")
                    print("     Type: \(metadata?.blockType ?? .text)")
                    print("     Content: '\(text.prefix(50))...'")
                    print("     Lines: \(lineCount)")
                    print("     Frame: \(boundingRect)")
                    print("     Text Length: \(text.count) chars")
                }
            }
        }
        print("======================\n")
    }
    
    /// Get the position (index) of the block at a given text location
    func getBlockPosition(at location: Int) -> Int? {
        var blockPosition = 0
        var foundPosition: Int? = nil
        
        let string = textStorage.string as NSString
        string.enumerateSubstrings(in: NSRange(location: 0, length: string.length),
                                  options: [.byParagraphs, .localized]) { (substring, range, enclosingRange, _) in
            
            let paragraphText = substring?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !paragraphText.isEmpty else { return }
            
            blockPosition += 1
            
            if NSLocationInRange(location, range) {
                foundPosition = blockPosition
            }
        }
        
        return foundPosition
    }
    
    // MARK: - Block Creation
    
    /// Add a new text block with the given content
    func addTextBlock(_ text: String, calorieData: String? = nil) {
        let blockText = text.isEmpty ? "\n" : text + "\n"
        
        // Create attributed string with proper font
        let attributedText = NSMutableAttributedString(string: blockText)
        attributedText.addAttribute(.font, value: self.font ?? UIFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: blockText.count))
        attributedText.addAttribute(.foregroundColor, value: self.textColor ?? UIColor.label, range: NSRange(location: 0, length: blockText.count))
        // Add paragraph style for spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 16
        attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: blockText.count))
        
        // Insert at the end
        let insertionPoint = textStorage.length
        textStorage.insert(attributedText, at: insertionPoint)
        
        // Set block metadata
        let blockRange = NSRange(location: insertionPoint, length: blockText.count)
        let metadata = UnifiedTextContentStorage.BlockMetadata(
            blockType: .text,
            blockSpacing: defaultBlockSpacing,
            imageReference: nil,
            calorieData: calorieData
        )
        
        unifiedContentStorage.setBlockMetadata(metadata, for: blockRange)
        
        // Force immediate update for programmatically added blocks
        forceUpdateParagraphBlocks()
    }
    
    /// Add a new image-text block with placeholder image and text
    func addImageBlock(_ text: String = "This is an image block with text flowing alongside. The image takes up 30% of the width while the text uses the remaining 70%.", imageReference: UUID? = nil, calorieData: String? = nil) {
        let blockText = text.isEmpty ? "\n" : text + "\n"
        let attributedText = NSMutableAttributedString(string: blockText)
        attributedText.addAttribute(.font, value: self.font ?? UIFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: blockText.count))
        attributedText.addAttribute(.foregroundColor, value: self.textColor ?? UIColor.label, range: NSRange(location: 0, length: blockText.count))
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 16
        attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: blockText.count))

        // Determine insertion point: always insert as a new paragraph at the current cursor
        var insertionPoint = selectedRange.location
        let string = textStorage.string as NSString
        // If not at start of a new line, insert a newline first
        if insertionPoint > 0 && (insertionPoint == string.length || string.character(at: insertionPoint - 1) != 10) {
            textStorage.insert(NSAttributedString(string: "\n"), at: insertionPoint)
            insertionPoint += 1
        }
        // Insert the image block at the insertion point
        textStorage.insert(attributedText, at: insertionPoint)
        // Set block metadata with image reference
        let blockRange = NSRange(location: insertionPoint, length: blockText.count)
        let metadata = UnifiedTextContentStorage.BlockMetadata(
            blockType: .imageText,
            blockSpacing: defaultBlockSpacing * 2, // Extra spacing for image blocks
            imageReference: imageReference ?? UUID(),
            calorieData: calorieData
        )
        unifiedContentStorage.setBlockMetadata(metadata, for: blockRange)
        print("DEBUG: Image block created at range \(blockRange)")
        // FORCE IMMEDIATE AND COMPLETE LAYOUT RECALCULATION
        forceCompleteLayoutUpdate()
        // Move cursor to the end of the new block
        selectedRange = NSRange(location: insertionPoint + blockText.count, length: 0)
    }
    
    /// Force a complete and immediate layout update - use for critical layout changes
    private func forceCompleteLayoutUpdate() {
        print("💥 FORCING COMPLETE LAYOUT UPDATE")
        
        // Step 1: Update exclusion paths first
        updateExclusionPaths()
        
        // Step 2: Force immediate processing of the layout changes
        // This is crucial - we need to ensure the layout manager processes the exclusion paths
        layoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textStorage.length), actualCharacterRange: nil)
        layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textStorage.length))
        
        // Step 3: Force synchronous layout of ALL text
        if textStorage.length > 0 {
            layoutManager.ensureLayout(forCharacterRange: NSRange(location: 0, length: textStorage.length))
        }
        
        // Step 4: Force immediate view layout
        setNeedsLayout()
        layoutIfNeeded() // This forces synchronous layout
        
        // Step 5: Update visual elements with the new layout
        updateImageViews()
        updateBlockBackgroundViews()
        
        // Step 6: Force display update
        setNeedsDisplay()
        
        // Step 7: Small delay to ensure text system has processed everything, then update again
        DispatchQueue.main.async {
            // Additional pass to ensure everything is updated
            self.setNeedsLayout()
            self.layoutIfNeeded()
            
            // Double-check exclusion paths are applied
            self.updateExclusionPaths()
            
            print("✅ Complete layout update finished")
        }
        
        // Reset the flag since we just updated everything
        needsExclusionPathUpdate = false
    }
    
    // MARK: - Block Updates
    
    /// Force immediate block update bypassing throttling - use for critical operations
    internal func forceUpdateParagraphBlocks() {
        print("🚀 Force update - bypassing throttling")
        
        // Reset throttling to allow immediate update
        lastUpdateTime = 0
        
        // Perform immediate update
        updateParagraphBlocks()
        
        // Check if we have any image blocks that need immediate layout update
        var hasImageBlocks = false
        unifiedContentStorage.enumerateParagraphs { _, metadata in
            if let metadata = metadata, metadata.blockType == .imageText {
                hasImageBlocks = true
            }
        }
        
        if hasImageBlocks {
            // Use complete layout update for image blocks
            forceCompleteLayoutUpdate()
        } else {
            // Standard update for text-only content
            updateExclusionPaths()
            updateImageViews()
            updateBlockBackgroundViews()
            
            // Force immediate layout and display update
            layoutIfNeeded()
            setNeedsDisplay()
            
            // Reset the flag since we just updated everything
            needsExclusionPathUpdate = false
        }
    }
    
    /// Update paragraph detection after text changes
    internal func updateParagraphBlocks(changedRange: NSRange? = nil) {
        let currentTime = CACurrentMediaTime()
        print("🔄 updateParagraphBlocks called at \(currentTime)")
        let timeSinceLastUpdate = currentTime - lastUpdateTime
        let shouldThrottle = timeSinceLastUpdate < updateThrottleInterval
        lastUpdateTime = currentTime
        let string = textStorage.string as NSString
        let isEmptyContent = string.length == 0
        let isFirstUpdate = currentBlockStructure.isEmpty
        if shouldThrottle && !isEmptyContent && !isFirstUpdate {
            print("⏰ Throttling update - too frequent (\(timeSinceLastUpdate)s since last)")
            DispatchQueue.main.asyncAfter(deadline: .now() + updateThrottleInterval) {
                self.updateParagraphBlocks(changedRange: changedRange)
            }
            return
        }
        var blockStructure = ""
        // Only clean up metadata for changed range if provided
        cleanupOrphanedMetadata(changedRange: changedRange)
        // Only enumerate paragraphs in changedRange if provided
        let enumerateRange = changedRange ?? NSRange(location: 0, length: string.length)
        unifiedContentStorage.enumerateParagraphs(in: enumerateRange) { paragraphRange, metadata in
            blockStructure += "\(paragraphRange.location):\(paragraphRange.length);"
            if let metadata = metadata {
                blockStructure += "\(metadata.blockType);"
            }
        }
        if blockStructure == currentBlockStructure && !isFirstUpdate {
            print("✅ Block structure unchanged - skipping update")
            return
        }
        print("🔧 Block structure changed - performing update for range: \(String(describing: changedRange))")
        var paragraphsProcessed = 0
        var metadataAssigned = 0
        string.enumerateSubstrings(in: enumerateRange, options: [.byParagraphs, .localized]) { (substring, range, enclosingRange, _) in
            paragraphsProcessed += 1
            guard let substring = substring, !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            let existingMetadata = self.unifiedContentStorage.blockMetadata(at: range.location)
            var forceTextBlock = false
            if range.location > 0 {
                let prevRange = NSRange(location: max(0, range.location - 1), length: 1)
                if let prevMetadata = self.unifiedContentStorage.blockMetadata(at: prevRange.location), prevMetadata.blockType == .imageText {
                    forceTextBlock = true
                }
            }
            if existingMetadata == nil || forceTextBlock {
                let isImageBlock = existingMetadata?.blockType == .imageText
                let metadata = UnifiedTextContentStorage.BlockMetadata(
                    blockType: (isImageBlock && !forceTextBlock) ? .imageText : .text,
                    blockSpacing: self.defaultBlockSpacing,
                    imageReference: (isImageBlock && !forceTextBlock) ? existingMetadata?.imageReference : nil,
                    calorieData: nil
                )
                self.unifiedContentStorage.setBlockMetadata(metadata, for: range)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.paragraphSpacing = 16
                self.textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
                metadataAssigned += 1
                print("📝 Auto-assigned text block metadata to paragraph at \(range.location)-\(range.location + range.length): '\(substring.prefix(30))...'")
            }
        }
        string.enumerateSubstrings(in: enumerateRange, options: [.byParagraphs, .localized]) { (substring, range, enclosingRange, _) in
            guard let substring = substring, !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            if self.unifiedContentStorage.blockMetadata(at: range.location) == nil {
                print("⚠️ WARNING: Paragraph at \(range.location)-\(range.location + range.length) still has no metadata after auto-assignment!")
                let metadata = UnifiedTextContentStorage.BlockMetadata(
                    blockType: .text,
                    blockSpacing: self.defaultBlockSpacing,
                    imageReference: nil,
                    calorieData: nil
                )
                self.unifiedContentStorage.setBlockMetadata(metadata, for: range)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.paragraphSpacing = 16
                self.textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
                print("🔧 Force-assigned metadata to paragraph: '\(substring.prefix(30))...'")
            }
        }
        print("🔄 updateParagraphBlocks: Processed \(paragraphsProcessed) paragraphs, assigned metadata to \(metadataAssigned) new blocks")
        currentBlockStructure = blockStructure
        needsExclusionPathUpdate = true
        setNeedsLayout()
        setNeedsDisplay()
    }
    
    /// Clean up metadata and image views for text ranges that no longer exist
    internal func cleanupOrphanedMetadata(changedRange: NSRange? = nil) {
        var validImageRefs = Set<UUID>()
        var validBlockKeys = Set<String>()
        let string = textStorage.string as NSString
        let enumerateRange = changedRange ?? NSRange(location: 0, length: string.length)
        if string.length > 0 {
            string.enumerateSubstrings(in: enumerateRange, options: [.byParagraphs, .localized]) { (substring, range, enclosingRange, _) in
                guard let substring = substring, !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return
                }
                if let metadata = self.unifiedContentStorage.blockMetadata(at: range.location) {
                    let blockKey = "\(range.location):\(range.length)"
                    validBlockKeys.insert(blockKey)
                    if metadata.blockType == .imageText, let imageRef = metadata.imageReference {
                        validImageRefs.insert(imageRef)
                    }
                }
            }
        }
        // Remove image views for orphaned image references (only in changed range if provided)
        var imagesToRemove: [UUID] = []
        for (imageRef, imageView) in imageViews {
            if !validImageRefs.contains(imageRef) {
                imageView.removeFromSuperview()
                imagesToRemove.append(imageRef)
            }
        }
        for imageRef in imagesToRemove {
            imageViews.removeValue(forKey: imageRef)
        }
        // Remove background views for orphaned block keys (only in changed range if provided)
        var backgroundsToRemove: [String] = []
        for (blockKey, backgroundView) in blockBackgroundViews {
            if !validBlockKeys.contains(blockKey) && !blockKey.contains("_separator") {
                backgroundView.removeFromSuperview()
                backgroundsToRemove.append(blockKey)
                let separatorKey = blockKey + "_separator"
                if let separatorView = blockBackgroundViews[separatorKey] {
                    separatorView.removeFromSuperview()
                    backgroundsToRemove.append(separatorKey)
                }
            }
        }
        for backgroundKey in backgroundsToRemove {
            blockBackgroundViews.removeValue(forKey: backgroundKey)
        }
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
} 
