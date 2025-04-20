import SwiftUI // Import needed for BlockPlaceholderView embedding
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
    
    // Calorie labels are now managed by TextEditorLayoutManager
    private var calorieLabels: [UILabel] = [] 
    private let layoutHelper = TextEditorLayoutManager() // Add instance of the layout manager
    
    // Track which paragraph has the cursor
    private var activeParagraphIndex: Int? = nil
    
    // New properties for exclusion path approach
    private var imagePlaceholderViews: [UIView] = [] // Holds the actual UIViews for placeholders
    private let imageMarkerCharacter = "\u{FFFC}" // Object Replacement Character
    
    // Debouncer for UI updates
    private var calorieUpdateWorkItem: DispatchWorkItem? = nil
    private let debounceDelay: TimeInterval = 0.1 // 100ms delay
    
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
        
        // Ensure layout manager is used for exclusion paths
        layoutManager.allowsNonContiguousLayout = false // Often needed for complex layouts

        // Listen for text changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange), // textDidChange will trigger layout update
            name: UITextView.textDidChangeNotification,
            object: self
        )
        
        // Set delegate to track selection changes
        self.delegate = self
    }
    
    // MARK: - Image Marker Insertion (Replaces Block Insertion)

    func insertImageMarkerAndText(with mockText: String) {
        guard let defaultFont = self.font else {
            print("Warning: Default font not available for text view.")
            return
        }

        // Define attributes for marker and text
        let commonAttributes: [NSAttributedString.Key: Any] = [.font: defaultFont]
        
        // Create attributed strings
        // Marker character - no text, just the special character
        let markerString = NSAttributedString(string: imageMarkerCharacter, attributes: commonAttributes)
        // Mock text WITH the default font attribute
        let mockTextString = NSAttributedString(string: " " + mockText, attributes: commonAttributes)

        // Get current cursor position or end of text
        let insertionRange = selectedRange

        // Get current attributed text
        let mutableAttributedString = NSMutableAttributedString(attributedString: textStorage)
        
        // Insert marker and text
        // Insert marker first, then text
        mutableAttributedString.insert(markerString, at: insertionRange.location)
        mutableAttributedString.insert(mockTextString, at: insertionRange.location + markerString.length)

        // Optional: Re-apply default font to whole range if needed, but might be less critical now
        // let fullRange = NSRange(location: 0, length: mutableAttributedString.length)
        // mutableAttributedString.addAttribute(.font, value: defaultFont, range: fullRange)

        // Replace the entire text storage
        textStorage.setAttributedString(mutableAttributedString)

        // --- DEBUG LOG --- 
        print("[DEBUG] Inserted marker. New textStorage string length: \(textStorage.length)")
        print("[DEBUG] TextStorage content:\n---START---\n\(textStorage.string)\n---END---")

        // Restore selection after the inserted content
        selectedRange = NSRange(location: insertionRange.location + markerString.length + mockTextString.length, length: 0)

        // Manually trigger textDidChange to update layout, paragraphs, calories
        textDidChange()
    }
    
    // MARK: - Text Processing
    
    // Handle text changes
    @objc private func textDidChange() {
        // --- DEBUG LOG --- 
        print("[DEBUG] textDidChange called.")

        // Notify about text changes
        onTextChanged?(text) // Existing callback
        
        // Existing paragraph/calorie update
        paragraphs.removeAll()
        calorieLabels.forEach { $0.removeFromSuperview() }
        calorieLabels.removeAll()
        updateParagraphs() // This needs to be aware of the image marker
        
        // Trigger layout update to reposition images/exclusion paths
        setNeedsLayout()
        layoutIfNeeded() // Force layout calculation immediately if needed
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
        // --- DEBUG LOG ---
        print("[DEBUG] updateParagraphs: Starting.")
        
        // Clear the main paragraphs array before processing
        // Note: This assumes calculateCalories callbacks handle out-of-bounds indices correctly
        self.paragraphs.removeAll() 
        
        let fullText = textStorage.string
        let nsText = fullText as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        // --- DEBUG LOG ---
        // Keep track of the actual index during enumeration
        var enumerationIndex = 0 
        
        nsText.enumerateSubstrings(in: fullRange, options: [.byParagraphs, .substringNotRequired]) { _, substringRange, enclosingRange, stop in
            // --- DEBUG LOG ---
            let currentEnumIndex = enumerationIndex
            enumerationIndex += 1
            print("[DEBUG] updateParagraphs: Enumeration index \(currentEnumIndex), Range: \(substringRange)")
            
            let paragraphText = nsText.substring(with: substringRange)
            // Exclude the marker character from calorie calculation text
            let textForCalories = paragraphText.replacingOccurrences(of: self.imageMarkerCharacter, with: "")
            let trimmedText = textForCalories.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // --- DEBUG LOG ---
            print("[DEBUG] updateParagraphs: Index \(currentEnumIndex), Text: \(paragraphText.prefix(30))..., Trimmed (for calories): \(trimmedText.prefix(30))...")

            if !trimmedText.isEmpty {
                // Create new paragraph info
                let newParagraph = ParagraphInfo(
                    range: substringRange,
                    text: paragraphText, // Store original text including marker
                    isLastParagraph: enclosingRange.upperBound == fullRange.upperBound
                )
                // Append directly to the main paragraphs array
                self.paragraphs.append(newParagraph)
                let newIndex = self.paragraphs.count - 1 // Get the index in the main array
                
                // --- DEBUG LOG ---
                print("[DEBUG] updateParagraphs: Appended paragraph directly. self.paragraphs count: \(self.paragraphs.count). New index: \(newIndex)")

                // Calculate calories based on text *without* the marker, using the correct index
                print("[DEBUG] updateParagraphs: Calling calculateCalories for index \(newIndex) with text: \(trimmedText.prefix(30))...")
                self.calculateCalories(for: newIndex, text: trimmedText)
            } else {
                // --- DEBUG LOG ---
                print("[DEBUG] updateParagraphs: Index \(currentEnumIndex) - Skipping empty/trimmed paragraph.")
            }
        }
        
        // --- DEBUG LOG ---
        print("[DEBUG] updateParagraphs: Finished enumeration. Final self.paragraphs count: \(paragraphs.count)")
        // No need to assign self.paragraphs = newParagraphs anymore
        
        // Update total calories and active paragraph (synchronous data)
        // Note: Total calories will be incomplete until async calculations finish
        updateTotalCalories() // Update based on currently available calories (likely 0 initially)
        updateActiveParagraph()
        
        // Trigger an initial display update (might show no labels yet)
        // The debounced update will catch the async results later.
        updateCalorieDisplay() 
    }
    
    // Calculate calories for a paragraph
    private func calculateCalories(for paragraphIndex: Int, text: String) {
        // Skip calculation for empty text
        if text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty { return }
        
        // --- DEBUG LOG ---
        print("[DEBUG] calculateCalories: Requesting calculation for index \(paragraphIndex), text: \(text.prefix(30))...")

        // Call the callback to calculate calories
        onNeedCalorieCalculation?(text) { [weak self] calories in
            // --- DEBUG LOG ---
            print("[DEBUG] calculateCalories CB: Received \(calories) kcal for original index \(paragraphIndex)")
            guard let self = self else {
                 print("[DEBUG] calculateCalories CB: Self is nil. Bailing.")
                 return
            }
            guard paragraphIndex < self.paragraphs.count else {
                // --- DEBUG LOG ---
                print("[DEBUG] calculateCalories CB: Index \(paragraphIndex) is out of bounds for current paragraphs count \(self.paragraphs.count). Bailing.")
                return 
            }
            
            // Update paragraph with calculated calories
            var updatedParagraph = self.paragraphs[paragraphIndex]
            // --- DEBUG LOG ---
            print("[DEBUG] calculateCalories CB: Updating paragraph at index \(paragraphIndex). Current text: \(updatedParagraph.text.prefix(30))... Current calories: \(updatedParagraph.calories ?? -1)")
            updatedParagraph.calories = calories
            self.paragraphs[paragraphIndex] = updatedParagraph
            // --- DEBUG LOG ---
            print("[DEBUG] calculateCalories CB: Updated paragraph at index \(paragraphIndex) with \(calories) kcal.")
            
            // Schedule a debounced UI update instead of immediate async
            self.scheduleCalorieDisplayUpdate()
        }
    }
    
    // Force recalculation of all paragraphs
    func recalculateAllParagraphs() {
        for (index, paragraph) in paragraphs.enumerated() {
            let textForCalories = paragraph.text.replacingOccurrences(of: self.imageMarkerCharacter, with: "")
            let trimmedText = textForCalories.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
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
    
    // Update the visual display of calories - Use TextEditorLayoutManager
    private func updateCalorieDisplay() {
        // --- DEBUG LOG ---
        print("[DEBUG] updateCalorieDisplay: Delegating to TextEditorLayoutManager.")
        
        // Call the layout manager to handle label creation and placement
        self.calorieLabels = layoutHelper.layoutCalorieLabels(
            labels: self.calorieLabels, 
            forParagraphs: self.paragraphs,
            inTextView: self,
            withActiveParagraph: self.activeParagraphIndex
        )
        
        // --- DEBUG LOG ---
        print("[DEBUG] updateCalorieDisplay: Layout manager returned \(self.calorieLabels.count) labels.")
        
        /* --- Remove old implementation ---
        calorieLabels.forEach { $0.removeFromSuperview() }
        calorieLabels.removeAll()
        
        print("[DEBUG] updateCalorieDisplay: Processing \(paragraphs.count) paragraphs.")
        
        for (index, paragraph) in paragraphs.enumerated() {
            guard let calories = paragraph.calories else { 
                // print("[DEBUG] updateCalorieDisplay: Paragraph \(index) has no calories. Text: \(paragraph.text.prefix(20))...")
                continue 
            }
            
            print("[DEBUG] updateCalorieDisplay: Paragraph \(index) HAS calories (\(calories)). Text: \(paragraph.text.prefix(30))...")

            let label = UILabel()
            label.text = "\(calories) kcal"
            label.font = .systemFont(ofSize: 16)
            label.textColor = .secondaryLabel
            label.sizeToFit()
            
            let paragraphRect = self.paragraphRect(for: paragraph)
            print("[DEBUG] updateCalorieDisplay: Paragraph \(index) rect: \(paragraphRect)")
            
            let labelX = bounds.width - label.bounds.width - 16
            let labelY = paragraphRect.maxY - label.bounds.height
            
            label.frame = CGRect(
                x: labelX,
                y: labelY, 
                width: label.bounds.width,
                height: label.bounds.height
            )
            print("[DEBUG] updateCalorieDisplay: Paragraph \(index) label frame: \(label.frame)")
            
            addSubview(label)
            calorieLabels.append(label)
        }
        print("[DEBUG] updateCalorieDisplay: Finished. Added \(calorieLabels.count) labels.")
        */
    }
    
    // MARK: - Debounced Update Logic
    
    private func scheduleCalorieDisplayUpdate() {
        // Invalidate any existing work item
        calorieUpdateWorkItem?.cancel()
        
        // Create a new work item
        let workItem = DispatchWorkItem { [weak self] in
            print("[DEBUG] Debouncer: Executing updateCalorieDisplay.")
            self?.updateTotalCalories() // Update total first
            self?.updateCalorieDisplay() // Then update labels
        }
        
        // Store the new work item
        calorieUpdateWorkItem = workItem
        
        // Schedule it to run after the delay on the main thread
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
        print("[DEBUG] Debouncer: Scheduled updateCalorieDisplay.")
    }
    
    // Override layoutSubviews to handle image placement and exclusion paths
    override func layoutSubviews() {
        super.layoutSubviews()
        // --- DEBUG LOG ---
        print("[DEBUG] layoutSubviews called.")
        updateImagePlaceholderViews()
        updateCalorieDisplay() // Call this after image layout
    }
    
    private func updateImagePlaceholderViews() {
        // Clear existing views and paths
        imagePlaceholderViews.forEach { $0.removeFromSuperview() }
        imagePlaceholderViews.removeAll()
        var newExclusionPaths: [UIBezierPath] = []
        
        // Constants for layout
        let placeholderWidth = self.bounds.width * 0.30
        let placeholderSize = CGSize(width: placeholderWidth, height: placeholderWidth)
        let horizontalPadding: CGFloat = 10 // Padding from left edge
        let verticalPadding: CGFloat = 5 // Padding above/below

        // Find marker characters by searching the string directly
        let fullText = textStorage.string
        let markerRanges = fullText.ranges(of: imageMarkerCharacter).map { NSRange($0, in: fullText) }
        
        // --- DEBUG LOG ---
        print("[DEBUG] Found \(markerRanges.count) marker character ranges: \(markerRanges)")

        for range in markerRanges {
            // --- DEBUG LOG --- 
            print("[DEBUG] Processing marker at range \(range)")
            
            // Found a marker, get its bounding rect
            // Use layoutManager correctly
            let layoutManager = self.layoutManager
            let textContainer = self.textContainer
            
            // Get glyph index for the start of the marker range
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: range.location)
            
            // Get the line fragment rect containing the glyph
            var effectiveRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange)
            // --- DEBUG LOG ---
            print("[DEBUG] Line fragment rect: \(lineRect), Effective range: \(effectiveRange)")
            
            // Check if lineRect is valid
            if lineRect.isEmpty || lineRect.isInfinite {
                 print("[DEBUG] Warning: Line fragment rect is invalid. Skipping. Rect: \(lineRect)")
                 continue
            }

            // Calculate frame for the placeholder view using lineRect
            let viewOrigin = CGPoint(x: textContainerInset.left + horizontalPadding,
                                     y: textContainerInset.top + lineRect.minY + verticalPadding) // Use lineRect.minY
            let viewFrame = CGRect(origin: viewOrigin, size: placeholderSize)
            // --- DEBUG LOG --- 
            print("[DEBUG] Calculated placeholder view frame: \(viewFrame)")
            
            // Create and add the placeholder view (using SwiftUI view via UIHostingController)
            // Consider reusing views later for performance
            let placeholderContentView = BlockPlaceholderView()
            let hostingController = UIHostingController(rootView: placeholderContentView)
            hostingController.view.frame = viewFrame
            hostingController.view.backgroundColor = .clear // Important for transparency
            // --- DEBUG LOG ---
            print("[DEBUG] Hosting controller view frame after setting: \(hostingController.view.frame)")
            
            addSubview(hostingController.view)
            imagePlaceholderViews.append(hostingController.view) // Store the container view
            // --- DEBUG LOG ---
            print("[DEBUG] Added placeholder subview. Current count: \(imagePlaceholderViews.count)")
            print("[DEBUG] Hosting controller view bounds after adding: \(hostingController.view.bounds)")
            
            // Create exclusion path (relative to text container origin) using lineRect
            let exclusionRect = CGRect(x: horizontalPadding,
                                       y: lineRect.minY + verticalPadding, // Use lineRect.minY
                                       width: max(1, placeholderSize.width + horizontalPadding), // Ensure > 0
                                       height: max(1, placeholderSize.height + (verticalPadding * 2))) // Ensure > 0
            let exclusionPath = UIBezierPath(rect: exclusionRect)
            newExclusionPaths.append(exclusionPath)
            // --- DEBUG LOG ---
            print("[DEBUG] Calculated exclusion rect: \(exclusionRect)")
        }
        
        // Apply exclusion paths
        textContainer.exclusionPaths = newExclusionPaths
        // --- DEBUG LOG ---
        print("[DEBUG] Applied \(newExclusionPaths.count) exclusion paths.")
        if !newExclusionPaths.isEmpty {
            print("[DEBUG] First exclusion path bounds: \(newExclusionPaths.first?.bounds)")
        }
    }
    
    // Clean up
    deinit {
        NotificationCenter.default.removeObserver(self)
        // Clean up hosting controllers if necessary
        imagePlaceholderViews.forEach { $0.removeFromSuperview() }
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
