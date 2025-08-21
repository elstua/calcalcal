import UIKit

// MARK: - Delegate Methods Extension

// MARK: - NSTextStorageDelegate

extension UnifiedTextView {
    
    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorage.EditActions, range editedRange: NSRange, changeInLength delta: Int) {
        // Respond to ALL content changes immediately, not just deletions
        guard editedMask.contains(.editedCharacters) else { return }
        
        print("🔄 Text storage changed: range=\(editedRange), delta=\(delta)")
        
        // Check if the edit affects an image block
        var affectsImageBlock = false
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard let metadata = metadata, metadata.blockType == .imageText else { return }
            
            // Check if the edited range intersects with this image block
            if NSIntersectionRange(editedRange, paragraphRange).length > 0 {
                affectsImageBlock = true
                print("📐 Edit affects image block at range \(paragraphRange)")
            }
        }
        
        // Update blocks immediately on EVERY character change
        // This prevents bugs caused by delayed updates
        DispatchQueue.main.async {

            // After updating, re-apply image block metadata to paragraphs that are still image blocks
            let string = self.textStorage.string as NSString
            self.unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
                guard let metadata = metadata, metadata.blockType == .imageText else { return }
                // If the paragraph still contains text, ensure metadata is present
                let paragraphText = string.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
                if !paragraphText.isEmpty {
                    self.unifiedContentStorage.setBlockMetadata(metadata, for: paragraphRange)
                }
            }
            
            // If this affects an image block, force immediate layout updates
            if affectsImageBlock {
                self.updateExclusionPaths()
                self.updateImageViews()
                self.updateBlockBackgroundViews()
                self.layoutIfNeeded()
                self.needsExclusionPathUpdate = false
            } else {
                // Force immediate visual updates for other blocks
                self.setNeedsLayout()
                self.setNeedsDisplay()
                
                // Mark exclusion paths for update
                self.needsExclusionPathUpdate = true
            }
        }
    }
}

// MARK: - UITextViewDelegate

extension UnifiedTextView {
    
    /// Helper to create a text block without mock calorie data
    func makeTextBlock(_ text: String) -> Block {
        return Block(type: .text(text), calorieData: nil)
    }
    
    func textViewDidChange(_ textView: UITextView) {
        print("📝 textViewDidChange called")
        print("Current textStorage: \(textStorage.string)")
        // Parse the text storage into blocks and update the model
        let string = textStorage.string as NSString
        var newBlocks: [Block] = []
        var location = 0
        while location < string.length {
            var paragraphStart = 0
            var paragraphEnd = 0
            var contentsEnd = 0
            string.getParagraphStart(&paragraphStart, end: &paragraphEnd, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))
            let paragraphRange = NSRange(location: paragraphStart, length: paragraphEnd - paragraphStart)
            let paragraphText = string.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
            print("Detected paragraph: '", paragraphText, "' at range: ", paragraphRange)
            if let metadata = unifiedContentStorage.blockMetadata(at: paragraphStart) {
                switch metadata.blockType {
                case .text:
                    newBlocks.append(Block(type: .text(paragraphText), calorieData: metadata.calorieData))
                case .imageText:
                    if let imageRef = metadata.imageReference, let image = imageMap[imageRef], let imageData = image.pngData() {
                        // Preserve both image and text
                        newBlocks.append(Block(type: .imageText(imageData, imageRef, paragraphText), calorieData: metadata.calorieData))
                    }
                case .spacer:
                    newBlocks.append(Block(type: .spacer, calorieData: nil))
                }
            } else {
                // Fallback: treat as text block
                newBlocks.append(makeTextBlock(paragraphText))
            }
            location = paragraphEnd
        }
        if newBlocks != self.blocks {
            print("Updating blocks array. New blocks: \(newBlocks)")
            let changedIndices = diffChangedBlockIndices(old: self.blocks, new: newBlocks)
            self.blocks = newBlocks
            if changedIndices.count == 0 {
                print("No block indices changed, skipping render.")
                return
            } else if changedIndices.count <= 2 {
                print("Partial update for block indices: \(changedIndices)")
                renderBlocks(affectedBlockIndices: changedIndices)
            } else {
                print("Full rebuild, too many blocks changed.")
                renderBlocks()
            }
        } else {
            print("No change to blocks array.")
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        print("🎯 Text will change: range=\(range), text='\(text)'")
        // Handle Enter key press in a model-driven way
        if text == "\n" {
            let cursorLocation = range.location
            // Find the block index and offset
            let string = textStorage.string as NSString
            var blockIndex: Int? = nil
            var blockStart = 0
            var blockEnd = 0
            var runningLocation = 0
            for (i, block) in blocks.enumerated() {
                switch block.type {
                case .text(let blockText):
                    let blockLength = (blockText + "\n").count
                    if cursorLocation >= runningLocation && cursorLocation <= runningLocation + blockLength {
                        blockIndex = i
                        blockStart = runningLocation
                        blockEnd = runningLocation + blockLength
                        break
                    }
                    runningLocation += blockLength
                case .image(let data, let uuid):
                    // Image blocks are 1 char (attachment) + newline
                    let blockLength = 2
                    if cursorLocation >= runningLocation && cursorLocation <= runningLocation + blockLength {
                        blockIndex = i
                        blockStart = runningLocation
                        blockEnd = runningLocation + blockLength
                        break
                    }
                    runningLocation += blockLength
                case .imageText(let data, let uuid, let text):
                    // Treat as a single block (1 char + text + newline)
                    let blockLength = (text + "\n").count + 1
                    if cursorLocation >= runningLocation && cursorLocation <= runningLocation + blockLength {
                        blockIndex = i
                        blockStart = runningLocation
                        blockEnd = runningLocation + blockLength
                        break
                    }
                    runningLocation += blockLength
                case .spacer:
                    let blockLength = 1 // newline
                    if cursorLocation >= runningLocation && cursorLocation <= runningLocation + blockLength {
                        blockIndex = i
                        blockStart = runningLocation
                        blockEnd = runningLocation + blockLength
                        break
                    }
                    runningLocation += blockLength
                }
                if blockIndex != nil { break }
            }
            guard let idx = blockIndex else { return true }
            var newBlocks = blocks
            var affectedIndices: [Int] = []
            switch blocks[idx].type {
            case .text(let blockText):
                // Split the text at the cursor offset
                let offsetInBlock = cursorLocation - blockStart
                let nsBlockText = blockText as NSString
                let left = nsBlockText.substring(to: max(0, min(offsetInBlock, nsBlockText.length)))
                let right = nsBlockText.substring(from: max(0, min(offsetInBlock, nsBlockText.length)))
                // Replace current block with left, insert new block with right
                newBlocks[idx] = makeTextBlock(left)
                newBlocks.insert(makeTextBlock(right), at: idx + 1)
                affectedIndices = [idx, idx + 1]
                self.blocks = newBlocks
                let caretLocation = blockStart + (left as NSString).length + 1 // +1 for newline
                renderBlocks(restoreCaretTo: caretLocation, affectedBlockIndices: affectedIndices)
                return false
            case .image(let data, let uuid):
                // Insert a new empty text block after the image
                newBlocks.insert(makeTextBlock(""), at: idx + 1)
                affectedIndices = [idx + 1]
                self.blocks = newBlocks
                let caretLocation = blockEnd + 1
                renderBlocks(restoreCaretTo: caretLocation, affectedBlockIndices: affectedIndices)
                return false
            case .imageText(let data, let uuid, let text):
                // Insert a new empty text block after the imageText block
                newBlocks.insert(makeTextBlock(""), at: idx + 1)
                affectedIndices = [idx + 1]
                self.blocks = newBlocks
                let caretLocation = blockEnd + 1
                renderBlocks(restoreCaretTo: caretLocation, affectedBlockIndices: affectedIndices)
                return false
            case .spacer:
                // Insert a new empty text block after the spacer
                newBlocks.insert(makeTextBlock(""), at: idx + 1)
                affectedIndices = [idx + 1]
                self.blocks = newBlocks
                let caretLocation = blockEnd + 1
                renderBlocks(restoreCaretTo: caretLocation, affectedBlockIndices: affectedIndices)
                return false
            }
        }
        
        // Handle deletion that might affect image blocks
        if text.isEmpty && range.length > 0 {
            // Check if we're deleting an image block
            let deletionRange = range
            
            // Check if any image blocks are being deleted
            unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
                guard let metadata = metadata,
                      metadata.blockType == .imageText else { return }
                
                // Check if this image block intersects with the deletion range
                if NSIntersectionRange(paragraphRange, deletionRange).length > 0 {
                    print("⚠️ Deleting image block at range \(paragraphRange)")
                    // The image will be deleted with the text, let the system handle it
                    // The text storage delegate will clean up the metadata
                }
            }
        }
        
        return true
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        // Even selection changes might require block updates
        // This ensures we stay synchronized with cursor position
        print("📍 Selection changed to: \(textView.selectedRange)")
        
        // Light update on selection change - just ensure visuals are correct
        setNeedsDisplay()
    }
}

// Utility: Diff two [Block] arrays and return indices of changed blocks
private func diffChangedBlockIndices(old: [Block], new: [Block]) -> [Int] {
    let count = max(old.count, new.count)
    var changed: [Int] = []
    for i in 0..<count {
        let oldBlock = i < old.count ? old[i] : nil
        let newBlock = i < new.count ? new[i] : nil
        if oldBlock != newBlock {
            changed.append(i)
        }
    }
    return changed
} 
