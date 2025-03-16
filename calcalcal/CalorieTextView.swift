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
    }
    
    // MARK: - Text Processing
    
    // Handle text changes
    @objc private func textDidChange() {
        // Notify about text changes
        onTextChanged?(text)
        
        // Process and update paragraphs
        updateParagraphs()
    }
    
    // Parse text into paragraphs and update their info
    private func updateParagraphs() {
        // Get all paragraph ranges
        let text = self.text
        let paragraphRanges = getParagraphRanges(for: text)
        
        // Build new paragraph info objects
        var newParagraphs: [ParagraphInfo] = []
        
        for range in paragraphRanges {
            let paragraphText = (text as NSString).substring(with: range)
            let trimmedText = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Try to find existing paragraph with matching text to preserve calories
            if let existingIndex = paragraphs.firstIndex(where: { 
                $0.text.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedText 
            }) {
                // Reuse existing calorie info but with updated range
                newParagraphs.append(ParagraphInfo(
                    id: paragraphs[existingIndex].id,
                    range: range,
                    text: paragraphText,
                    calories: paragraphs[existingIndex].calories
                ))
            } else {
                // Create new paragraph info
                let newParagraph = ParagraphInfo(range: range, text: paragraphText)
                newParagraphs.append(newParagraph)
                
                // Calculate calories for non-empty paragraphs
                if !trimmedText.isEmpty {
                    calculateCalories(for: newParagraphs.count - 1, text: trimmedText)
                }
            }
        }
        
        paragraphs = newParagraphs
        updateTotalCalories()
        updateCalorieDisplay()
    }
    
    // Get NSRanges for each paragraph in text
    private func getParagraphRanges(for text: String) -> [NSRange] {
        var paragraphRanges: [NSRange] = []
        
        // Empty text case
        if text.isEmpty {
            paragraphRanges.append(NSRange(location: 0, length: 0))
            return paragraphRanges
        }
        
        // Use NSString for easier range handling
        let nsText = text as NSString
        
        // Find paragraph ranges using NSString enumeration
        let fullRange = NSRange(location: 0, length: nsText.length)
        
        nsText.enumerateSubstrings(in: fullRange, options: .byParagraphs) { (substring, substringRange, _, _) in
            if let _ = substring {
                paragraphRanges.append(substringRange)
            }
        }
        
        // If no paragraphs were found (shouldn't happen), return the full range
        if paragraphRanges.isEmpty {
            paragraphRanges.append(fullRange)
        }
        
        return paragraphRanges
    }
    
    // Calculate calories for a paragraph
    private func calculateCalories(for paragraphIndex: Int, text: String) {
        // Skip calculation for empty text
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        
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
            let trimmedText = paragraph.text.trimmingCharacters(in: .whitespacesAndNewlines)
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
        // Clear existing labels
        calorieLabels.forEach { $0.removeFromSuperview() }
        calorieLabels.removeAll()
        
        // Create new labels for each paragraph with calories
        for paragraph in paragraphs {
            if let calories = paragraph.calories, !paragraph.isEmpty {
                // Get position for calorie label
                let textRect = caloriePosition(for: paragraph)
                
                // Create label
                let label = UILabel()
                label.text = "\(calories) kcal"
                label.font = .systemFont(ofSize: 16)
                label.textColor = .secondaryLabel
                label.sizeToFit()
                
                // Position label
                label.frame = CGRect(
                    x: bounds.width - label.bounds.width - 16,
                    y: textRect.minY,
                    width: label.bounds.width,
                    height: label.bounds.height
                )
                
                // Add to view
                addSubview(label)
                calorieLabels.append(label)
            }
        }
    }
    
    // Calculate position for calorie label based on paragraph position
    private func caloriePosition(for paragraph: ParagraphInfo) -> CGRect {
        // For empty text
        if text.isEmpty || paragraph.range.length == 0 {
            return CGRect(x: 0, y: 0, width: 0, height: 0)
        }
        
        // Get bounding rect for paragraph
        let glyphRange = layoutManager.glyphRange(forCharacterRange: paragraph.range, actualCharacterRange: nil)
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