import UIKit

// MARK: - Delegate Methods Extension

// MARK: - NSTextStorageDelegate

extension UnifiedTextView {
    
    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorage.EditActions, range editedRange: NSRange, changeInLength delta: Int) {
        if isProgrammaticUpdate { return }
        // Skip updates while the user is composing text (IME)
        if self.markedTextRange != nil { return }
        // Mark last user edit time for external-sync suppression
        lastUserEditAt = CACurrentMediaTime()
        // Respond to character changes only
        guard editedMask.contains(.editedCharacters) else { return }
        
        #if DEBUG
        print("🔄 Text storage changed: range=\(editedRange), delta=\(delta)")
        #endif
        
        // Check if the edit affects an image block
        var affectsImageBlock = false
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard let metadata = metadata, metadata.blockType == .imageText else { return }
            
            // Check if the edited range intersects with this image block
            if NSIntersectionRange(editedRange, paragraphRange).length > 0 {
                affectsImageBlock = true
                #if DEBUG
                print("📐 Edit affects image block at range \(paragraphRange)")
                #endif
            }
        }
        
        // Update blocks on character changes
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isProgrammaticUpdate else { return }

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
                self.needsExclusionPathUpdate = false
            } else {
                // Throttle visual updates for other blocks
                self.scheduleThrottledLayoutUpdate()
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
        if isProgrammaticUpdate { return }
        // Skip updates while the user is composing text (IME)
        if textView.markedTextRange != nil { return }
        #if DEBUG
        print("📝 textViewDidChange called")
        print("Current textStorage: \(textStorage.string)")
        #endif
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
            var paragraphText = string.substring(with: paragraphRange)
            if paragraphText.hasSuffix("\n") {
                paragraphText.removeLast()
            }
            #if DEBUG
            print("Detected paragraph: '", paragraphText, "' at range: ", paragraphRange)
            #endif
            if let metadata = unifiedContentStorage.blockMetadata(at: paragraphStart) {
                switch metadata.blockType {
                case .text:
                    var nutrition: NutritionData? = nil
                    if let data = metadata.nutritionJSON {
                        nutrition = try? JSONDecoder().decode(NutritionData.self, from: data)
                    }
                    newBlocks.append(Block(type: .text(paragraphText), calorieData: metadata.calorieData, nutrition: nutrition))
                case .imageText:
                    if let imageRef = metadata.imageReference, let image = imageMap[imageRef], let imageData = image.pngData() {
                        // Preserve both image and text
                        var nutrition: NutritionData? = nil
                        if let d = metadata.nutritionJSON {
                            nutrition = try? JSONDecoder().decode(NutritionData.self, from: d)
                        }
                        newBlocks.append(Block(type: .imageText(imageData, imageRef, paragraphText), calorieData: metadata.calorieData, nutrition: nutrition))
                    }
                case .spacer:
                    newBlocks.append(Block(type: .spacer, calorieData: nil, nutrition: nil))
                }
            } else {
                // Fallback: treat as text block
                newBlocks.append(makeTextBlock(paragraphText))
            }
            location = paragraphEnd
        }
        // Only update local blocks snapshot; rendering is centralized via SwiftUI's updateUIView
        if newBlocks != self.blocks {
            // Detect if user edited any previously saved (analyzed) paragraph
            let changed = diffChangedBlockIndices(old: self.blocks, new: newBlocks)
            let editedPreviouslySaved = changed.contains { idx in
                guard idx < self.blocks.count else { return false }
                return self.blocks[idx].nutrition != nil || (self.blocks[idx].calorieData != nil)
            }
            #if DEBUG
            print("Updating blocks array (no immediate render). New blocks: \(newBlocks)")
            if editedPreviouslySaved { print("✏️ Edited a previously saved paragraph") }
            #endif
            // Update both local and SwiftUI snapshots to keep them aligned and prevent external diff from forcing re-render
            self.blocks = newBlocks
            if editedPreviouslySaved {
                // Notify listeners (e.g., overlay) to trigger a debounced autosave
                NotificationCenter.default.post(name: .editorSavedParagraphEdited, object: nil)
            }
        } else {
            #if DEBUG
            print("No change to blocks array.")
            #endif
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if isProgrammaticUpdate { return false }
        isUserEditing = true
        print("🎯 Text will change: range=\(range), text='\(text)'")
        // Let the system handle Enter/newline insertion to prevent forced newlines and caret jumps
        if text == "\n" {
            #if DEBUG
            print("↩️ Enter pressed – committing paragraph")
            #endif
            // Defer notification to after system commits the newline
            DispatchQueue.main.async {
                #if DEBUG
                print("📣 Posting editorParagraphCommitted notification")
                #endif
                NotificationCenter.default.post(name: .editorParagraphCommitted, object: nil)
            }
            return true
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
                    #if DEBUG
                    print("⚠️ Deleting image block at range \(paragraphRange)")
                    #endif
                    // The image will be deleted with the text, let the system handle it
                    // The text storage delegate will clean up the metadata
                }
            }
        }
        
        return true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        // Attempt to apply any pending external updates once the user stops editing
        applyPendingExternalBlocksIfIdle(idleGrace: 0)
        // Final autosave when editing session ends
        NotificationCenter.default.post(name: .editorSavedParagraphEdited, object: nil)
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        if isProgrammaticUpdate { return }
        // Even selection changes might require block updates
        // This ensures we stay synchronized with cursor position
        print("📍 Selection changed to: \(textView.selectedRange)")
        
        // Light update on selection change - just ensure visuals are correct
        setNeedsDisplay()
        // End of an edit gesture when selection change happens after input
        isUserEditing = false
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
