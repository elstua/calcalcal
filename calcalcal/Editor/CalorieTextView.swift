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
    
    // Callback for paragraph action button
    var onParagraphActionButtonTapped: ((Int) -> Void)?
    
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
    
    // Action button that appears next to the active paragraph
    private var actionButton: UIButton?
    
    // Track if there's an "implicit" empty line at the end
    private var hasImplicitEmptyLine: Bool = false
    
    // Managers for improved functionality
    private let cursorManager = CursorPositionManager()
    private let uiElementsLayoutManager = TextEditorLayoutManager()

    // MARK: - Initialization
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupTextView()
        setupManagers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextView()
        setupManagers()
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
        
        // Create action button
        setupActionButton()
    }
    
    private func setupManagers() {
        // Configure cursor position manager
        cursorManager.onCursorPositionChanged = { [weak self] position, activeIndex, hasImplicitLine in
            guard let self = self else { return }
            
            // Update state
            self.activeParagraphIndex = activeIndex
            self.hasImplicitEmptyLine = hasImplicitLine
            
            // Update UI
            self.updateActionButtonPosition()
        }
    }
    
    private func setupActionButton() {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        button.tintColor = .systemOrange
        button.isHidden = false // Always show the button
        button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        
        // Size the button
        button.frame = CGRect(x: 0, y: 0, width: 26, height: 26)
        
        addSubview(button)
        self.actionButton = button
    }
    
    @objc private func actionButtonTapped() {
        if let activeParagraphIndex = activeParagraphIndex {
            onParagraphActionButtonTapped?(activeParagraphIndex)
        } else if hasImplicitEmptyLine {
            // For the implicit empty line at the end (or empty document)
            onParagraphActionButtonTapped?(paragraphs.count > 0 ? paragraphs.count - 1 : 0)
        }
    }
    
    // MARK: - Text Processing
    
    // Handle text changes
    @objc private func textDidChange() {
        // Notify about text changes
        onTextChanged?(text)
        
        // Process and update paragraphs
        updateParagraphs()
    }
    
    // Update which paragraph is active based on cursor position
    private func updateActiveParagraph() {
        // Use the cursor manager to determine active paragraph
        cursorManager.updateCursorPosition(
            position: selectedRange.location,
            inText: text ?? "",
            withParagraphs: paragraphs
        )
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
            
            // Try to find existing paragraph with matching text to preserve calories
            if let existingIndex = paragraphs.firstIndex(where: {
                $0.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == trimmedText
            }) {
                // Reuse existing calorie info but with updated range
                newParagraphs.append(ParagraphInfo(
                    id: paragraphs[existingIndex].id,
                    range: range,
                    text: paragraphText,
                    calories: paragraphs[existingIndex].calories,
                    isActive: index == activeParagraphIndex,
                    isLastParagraph: index == paragraphRanges.count - 1
                ))
            } else {
                // Create new paragraph info
                let newParagraph = ParagraphInfo(
                    range: range,
                    text: paragraphText,
                    isActive: index == activeParagraphIndex,
                    isLastParagraph: index == paragraphRanges.count - 1
                )
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
        updateActiveParagraph() // Update which paragraph has the cursor
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
        
        // Track the last ending position to detect empty lines
        var lastEndPosition = 0
        
        nsText.enumerateSubstrings(in: fullRange, options: .byParagraphs) { (substring, substringRange, _, _) in
            // Check for empty lines before this paragraph
            if substringRange.location > lastEndPosition {
                let emptyLineRange = NSRange(location: lastEndPosition, length: substringRange.location - lastEndPosition)
                paragraphRanges.append(emptyLineRange)
            }
            
            // Add the current paragraph
            if substring != nil {
                paragraphRanges.append(substringRange)
            }
            
            lastEndPosition = substringRange.location + substringRange.length
        }
        
        // Check for trailing empty line
        if lastEndPosition < nsText.length {
            let trailingEmptyLineRange = NSRange(location: lastEndPosition, length: nsText.length - lastEndPosition)
            paragraphRanges.append(trailingEmptyLineRange)
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
    
    // Update the visual display of calories using the layout manager
    private func updateCalorieDisplay() {
        // Use layout manager to position calorie labels
        calorieLabels = uiElementsLayoutManager.layoutCalorieLabels(
            labels: calorieLabels,
            forParagraphs: paragraphs,
            inTextView: self,
            withActiveParagraph: activeParagraphIndex
        )
    }
    
    // Update the position of the action button using the layout manager
    private func updateActionButtonPosition() {
        guard let button = actionButton else { return }
        
        // Get the active paragraph if any
        let activeParagraph = activeParagraphIndex.flatMap { index in
            paragraphs.indices.contains(index) ? paragraphs[index] : nil
        }
        
        // Use layout manager to position button
        uiElementsLayoutManager.layoutButton(
            buttonView: button,
            forParagraph: activeParagraph,
            inTextView: self,
            withCursorPosition: selectedRange.location,
            hasImplicitEmptyLine: hasImplicitEmptyLine
        )
        
        // Ensure button is visible
        bringSubviewToFront(button)
    }
    
    // Override layout to update calorie displays and action button
    override func layoutSubviews() {
        super.layoutSubviews()
        updateCalorieDisplay()
        updateActionButtonPosition()
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
