import UIKit

class BlockBasedTextStorage: NSTextStorage {
    private var backingStore = NSMutableAttributedString()

    override var string: String {
        return backingStore.string
    }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: (str as NSString).length - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    override func processEditing() {
        super.processEditing() // Allow superclass to perform its processing first

        // Determine the range of the entire document.
        // For optimization later, this could be narrowed to the edited paragraphs.
        let documentRange = NSRange(location: 0, length: self.length)

        // Remove any .blockType attributes in the entire document before re-applying.
        // This ensures that attributes are fresh after each edit.
        // This operation will call our overridden `setAttributes` which handles editing calls.
        self.removeAttribute(.blockType, range: documentRange)

        // Enumerate paragraphs in the document string and apply the .textBlock attribute.
        (self.string as NSString).enumerateSubstrings(in: documentRange, options: .byParagraphs) { (substring, substringRange, enclosingRange, stop) in
            // Apply the .textBlock attribute to the current paragraph range.
            // This also goes through our `setAttributes` method.
            self.addAttribute(.blockType, value: BlockType.textBlock.rawValue, range: substringRange)
        }
        
        // After attributing paragraphs, specifically re-attribute calorie markers
        // to ensure their type is not overridden by the general textBlock type.
        // Note: We need a reference to the actual character used for calorie markers.
        // For now, we'll assume it's accessible or define it here if it's simple enough.
        // Let's use the standard object replacement character for this example.
        let calorieMarkerChar = "\u{FFFC}" // Object Replacement Character

        var searchRange = NSRange(location: 0, length: self.length)
        while searchRange.location < self.length {
            let foundRange = (self.string as NSString).range(of: calorieMarkerChar, options: [], range: searchRange)
            if foundRange.location != NSNotFound {
                // Check if this character ALREADY has a calorieMarker attribute from insertion.
                // If not, or to be safe, re-apply.
                // For robust handling, insertion should be the primary source of this attribute.
                // This step here is more of a safeguard or for cases where markers might be pasted/loaded.
                self.addAttribute(.blockType, value: BlockType.calorieMarker.rawValue, range: foundRange)
                
                searchRange = NSRange(location: foundRange.upperBound, length: self.length - foundRange.upperBound)
            } else {
                break // No more markers found
            }
        }

        // Note: Default font attributes should ideally be handled by super.processEditing()
        // or applied here if necessary. For now, we focus on the blockType.
    }
    
    // Convenience initializer
    convenience init(text: String) {
        self.init()
        backingStore.replaceCharacters(in: NSRange(location: 0, length: 0), with: text)
    }
} 