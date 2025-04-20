import UIKit

class CalorieTextView: UITextView {
    // MARK: - Properties
    
    // Track paragraphs and their calorie information
    private(set) var paragraphs: [ParagraphInfo] = []
    
    // Callback for when calories need to be calculated
    var onNeedCalorieCalculation: ((String, @escaping (Int) -> Void) -> Void)?
    
    // Callback for total calories update
    var onTotalCaloriesChanged: ((Int) -> Void)?
    
    // Callback when text changes
    var onTextChanged: ((String) -> Void)?
    
    // Store calculated total
    private var totalCalories: Int = 0 {
        didSet {
            onTotalCaloriesChanged?(totalCalories)
        }
    }
    
    // For handling calorie display
    private var calorieLabels: [UILabel] = []
    
    // Track which paragraph has the cursor
    private var activeParagraphIndex: Int? = nil
    
    // MARK: - Initialization
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupTextView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextView()
    }
    
    private func setupTextView() {
        // Setup text view with custom container inset to leave room for calorie display
        backgroundColor = .clear
        font = .systemFont(ofSize: 18)
        textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 90) // Extra right inset for calories
        
        // Listen for text changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: UITextView.textDidChangeNotification,
            object: self
        )
        
        // Set delegate to track selection changes
        self.delegate = self
    }
    
    // MARK: - Block Insertion (New)

    func insertBlockPlaceholder(with mockText: String) {
        guard let placeholderImage = createPlaceholderImage() else { return }

        // Create attachment
        let attachment = NSTextAttachment()
        attachment.image = placeholderImage

        // Calculate size (30% of width, 1:1 ratio)
        let width = self.bounds.width * 0.30
        attachment.bounds = CGRect(x: 0, y: -4, width: width, height: width) // Small y offset for better alignment

        // Create attributed strings
        let attachmentString = NSAttributedString(attachment: attachment)
        let mockTextString = NSAttributedString(string: " " + mockText) // Add space before mock text

        // Get current cursor position or end of text
        let insertionRange = selectedRange

        // Insert into text storage
        let mutableAttributedString = NSMutableAttributedString(attributedString: textStorage)
        mutableAttributedString.insert(attachmentString, at: insertionRange.location)
        mutableAttributedString.insert(mockTextString, at: insertionRange.location + attachmentString.length)

        // Replace the entire text storage to ensure updates
        // This is simpler than trying to manage partial updates and notifications
        // but might have performance implications for very large text.
        // We might need to refine this later if needed.
        let oldSelectedRange = selectedRange // Preserve selection
        textStorage.setAttributedString(mutableAttributedString)

        // Restore selection after the inserted content
        selectedRange = NSRange(location: insertionRange.location + attachmentString.length + mockTextString.length, length: 0)

        // Manually trigger textDidChange to update paragraphs/calories
        // Note: setAttributedString might trigger this, but explicit call ensures it.
        textDidChange()
    }

    private func createPlaceholderImage() -> UIImage? {
        let size = CGSize(width: 50, height: 50) // Actual size doesn't matter much here, bounds control it
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        UIColor.lightGray.setFill()
        context.fill(CGRect(origin: .zero, size: size))

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    // MARK: - Text Processing
    
    // Handle text changes
    @objc private func textDidChange() {
        // Notify about text changes
        onTextChanged?(text)
        
        // Clear existing paragraphs and labels
        paragraphs.removeAll()
        calorieLabels.forEach { $0.removeFromSuperview() }
        calorieLabels.removeAll()
        
        // Process and update paragraphs
        updateParagraphs()
    }
    
    // Update which paragraph is active based on cursor position
    private func updateActiveParagraph() {
        // Determine active paragraph based on cursor position
        let cursorPosition = selectedRange.location
        activeParagraphIndex = paragraphs.firstIndex { paragraph in
            let range = paragraph.range
            return cursorPosition >= range.location && cursorPosition <= range.location + range.length
        }
    }
    
    // Parse text into paragraphs and update their info
    private func updateParagraphs() {
        // Get all paragraph ranges
        let text = self.text ?? ""
        let paragraphRanges = getParagraphRanges(for: text)
        
        // Build new paragraph info objects
        var newParagraphs: [ParagraphInfo] = []
        
        for (index, range) in paragraphRanges.enumerated() {
            let paragraphText = (text as NSString).substring(with: range)
            let trimmedText = paragraphText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            // Skip empty paragraphs
            if trimmedText.isEmpty {
                continue
            }
            
            // Create new paragraph info
            let newParagraph = ParagraphInfo(
                range: range,
                text: paragraphText,
                isLastParagraph: index == paragraphRanges.count - 1
            )
            newParagraphs.append(newParagraph)
        }
        
        // Update paragraphs first
        paragraphs = newParagraphs
        
        // Then calculate calories for each paragraph
        for (index, paragraph) in paragraphs.enumerated() {
            let trimmedText = paragraph.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !trimmedText.isEmpty {
                calculateCalories(for: index, text: trimmedText)
            }
        }
        
        updateTotalCalories()
        updateCalorieDisplay()
        updateActiveParagraph() // Update which paragraph has the cursor
    }
    
    // Get NSRanges for each paragraph in text
    private func getParagraphRanges(for text: String) -> [NSRange] {
        var paragraphRanges: [NSRange] = []
        
        // Empty text case - return empty array
        if text.isEmpty {
            return paragraphRanges
        }
        
        // Use NSString for easier range handling
        let nsText = text as NSString
        
        // Find paragraph ranges using NSString enumeration
        let fullRange = NSRange(location: 0, length: nsText.length)
        
        nsText.enumerateSubstrings(in: fullRange, options: .byParagraphs) { (substring, substringRange, _, _) in
            // Only add non-empty paragraphs
            if let substring = substring, !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                paragraphRanges.append(substringRange)
            }
        }
        
        return paragraphRanges
    }
    
    // Calculate calories for a paragraph
    private func calculateCalories(for paragraphIndex: Int, text: String) {
        // Skip calculation for empty text
        if text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty { return }
        
        // Call the callback to calculate calories
        onNeedCalorieCalculation?(text) { [weak self] calories in
            guard let self = self, paragraphIndex < self.paragraphs.count else { return }
            
            // Update paragraph with calculated calories
            var updatedParagraph = self.paragraphs[paragraphIndex]
            updatedParagraph.calories = calories
            self.paragraphs[paragraphIndex] = updatedParagraph
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.updateTotalCalories()
                self.updateCalorieDisplay()
            }
        }
    }
    
    // Force recalculation of all paragraphs
    func recalculateAllParagraphs() {
        for (index, paragraph) in paragraphs.enumerated() {
            let trimmedText = paragraph.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !trimmedText.isEmpty {
                calculateCalories(for: index, text: trimmedText)
            }
        }
    }
    
    // MARK: - UI Updates
    
    // Update the total calories count
    private func updateTotalCalories() {
        let total = paragraphs.compactMap { $0.calories }.reduce(0, +)
        totalCalories = total
    }
    
    // Update the visual display of calories
    private func updateCalorieDisplay() {
        // Remove existing labels
        calorieLabels.forEach { $0.removeFromSuperview() }
        calorieLabels.removeAll()
        
        // Create new labels for each paragraph with calories
        for paragraph in paragraphs {
            guard let calories = paragraph.calories else { continue }
            
            // Create and configure label
            let label = UILabel()
            label.text = "\(calories) kcal"
            label.font = .systemFont(ofSize: 16)
            label.textColor = .secondaryLabel
            label.sizeToFit()
            
            // Get paragraph position
            let paragraphRect = self.paragraphRect(for: paragraph)
            
            // Position label
            label.frame = CGRect(
                x: bounds.width - label.bounds.width - 16,
                y: paragraphRect.maxY - label.bounds.height,
                width: label.bounds.width,
                height: label.bounds.height
            )
            
            // Add to text view and track
            addSubview(label)
            calorieLabels.append(label)
        }
    }
    
    // Get rectangle for a paragraph
    private func paragraphRect(for paragraph: ParagraphInfo) -> CGRect {
        let layoutManager = self.layoutManager
        let textContainer = self.textContainer
        
        // Convert character range to glyph range
        let glyphRange = layoutManager.glyphRange(forCharacterRange: paragraph.range, 
                                                actualCharacterRange: nil)
        
        // Find the bounding rect for the glyphs
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // Adjust for text container insets
        rect.origin.x += textContainerInset.left
        rect.origin.y += textContainerInset.top
        
        return rect
    }
    
    // Override layout to update calorie displays
    override func layoutSubviews() {
        super.layoutSubviews()
        updateCalorieDisplay()
    }
    
    // Clean up
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UITextViewDelegate Extension
extension CalorieTextView: UITextViewDelegate {
    // Track selection changes through the delegate
    func textViewDidChangeSelection(_ textView: UITextView) {
        updateActiveParagraph()
    }
    
    // Handle text view becoming first responder
    func textViewDidBeginEditing(_ textView: UITextView) {
        updateActiveParagraph()
    }
}
