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
            self.updateParagraphBlocks(changedRange: editedRange)
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
    
    func textViewDidChange(_ textView: UITextView) {
        print("📝 Text view did change - triggering immediate block update")
        
        // Update paragraph blocks immediately on every change
        updateParagraphBlocks()
        
        // Check if current cursor is in an image block
        let currentLocation = selectedRange.location
        var isInImageBlock = false
        
        if currentLocation > 0 && currentLocation <= textStorage.length {
            if let metadata = unifiedContentStorage.blockMetadata(at: currentLocation) {
                isInImageBlock = metadata.blockType == .imageText
            }
        }
        
        if isInImageBlock {
            // For image blocks, force aggressive layout updates to ensure text flows correctly
            print("🖼️ Text change in image block - forcing complete layout update")
            
            // Use a micro-delay to ensure text storage changes are processed first
            DispatchQueue.main.async {
                // Force complete layout recalculation
                self.updateExclusionPaths()
                
                // Force immediate processing
                self.layoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: self.textStorage.length), actualCharacterRange: nil)
                if self.textStorage.length > 0 {
                    self.layoutManager.ensureLayout(forCharacterRange: NSRange(location: 0, length: self.textStorage.length))
                }
                
                // Update visual elements
                self.updateImageViews()
                self.updateBlockBackgroundViews()
                
                // Force synchronous layout
                self.setNeedsLayout()
                self.layoutIfNeeded()
                self.setNeedsDisplay()
                
                self.needsExclusionPathUpdate = false
            }
        } else {
            // Force immediate redraw and layout updates for other blocks
            setNeedsDisplay()
            setNeedsLayout()
            
            // Ensure exclusion paths are updated
            needsExclusionPathUpdate = true
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        print("🎯 Text will change: range=\(range), text='\(text)'")
        
        // Pre-emptively prepare for the change
        // This helps ensure we're ready for the update
        
        // Handle Enter key press
        if text == "\n" {
            // Check if we're at the end of an image block
            let currentLocation = range.location
            let currentMetadata = unifiedContentStorage.blockMetadata(at: currentLocation)
            
            if let metadata = currentMetadata, metadata.blockType == .imageText {
                // Check if we're at or near the end of the paragraph
                var paragraphEnd = 0
                let string = textStorage.string as NSString
                string.getParagraphStart(nil, end: &paragraphEnd, contentsEnd: nil, 
                                       for: NSRange(location: currentLocation, length: 0))
                
                // If we're at the end of the paragraph or close to it
                if currentLocation >= paragraphEnd - 2 {
                    // Create a new text block instead of continuing the image block
                    DispatchQueue.main.async {
                        self.addTextBlock("")
                        // Force immediate update after adding block
                        self.updateParagraphBlocks()
                    }
                    return false // Prevent the default newline behavior
                }
            } else {
                // Insert a spacer, then a new paragraph
                addSpacerBlock()
                let newline = NSAttributedString(string: "\n")
                textStorage.insert(newline, at: selectedRange.location)
                // Set font and paragraph style for the new paragraph
                let font = self.font ?? UIFont.systemFont(ofSize: 16)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.paragraphSpacing = 0
                let newParagraphRange = NSRange(location: selectedRange.location, length: 1)
                textStorage.addAttribute(.font, value: font, range: newParagraphRange)
                textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: newParagraphRange)
                selectedRange = NSRange(location: selectedRange.location + 1, length: 0)
                return false // Prevent default behavior
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
        
        // Schedule immediate update after this change completes
        DispatchQueue.main.async {
            self.updateParagraphBlocks()
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