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
        let documentRange = NSRange(location: 0, length: self.length)

        // First pass: Apply default text block type to all paragraphs
        (self.string as NSString).enumerateSubstrings(in: documentRange, options: .byParagraphs) { (substring, substringRange, enclosingRange, stop) in
            // Check if this paragraph contains an image marker
            if let substring = substring, substring.contains("\u{FFFC}") {
                // This is an image block - apply image placeholder type
                self.addAttribute(.blockType, value: BlockType.imagePlaceholder.rawValue, range: substringRange)
            } else {
                // Regular text block
                self.addAttribute(.blockType, value: BlockType.textBlock.rawValue, range: substringRange)
            }
        }
        
        // Note: We don't need the calorie marker logic anymore since we're using automatic paragraph detection
    }
    
    // Convenience initializer
    convenience init(text: String) {
        self.init()
        backingStore.replaceCharacters(in: NSRange(location: 0, length: 0), with: text)
    }
}
