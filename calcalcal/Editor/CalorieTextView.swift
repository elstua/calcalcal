import SwiftUI // Import needed for BlockPlaceholderView embedding
import UIKit

// Removed ParagraphInfo struct from here, it's now in TextBlockTypes.swift

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
    
    // Character used to mark where a calorie count should be displayed for a block
    // let calorieMarkerCharacter = "\u{FFFC}" // Removed - No longer using explicit marker character
    
    // New properties for exclusion path approach (COMMENTED OUT FOR NOW)
    // private var imagePlaceholderViews: [UIView] = [] // Holds the actual UIViews for placeholders
    
    // Debouncer for UI updates
    private var calorieUpdateWorkItem: DispatchWorkItem? = nil
    private let debounceDelay: TimeInterval = 0.1 // 100ms delay
    
    // MARK: - Initialization
    
    // Custom initializer to use BlockBasedTextStorage
    init(frame: CGRect, customTextStorage: BlockBasedTextStorage) {
        let layoutManager = NSLayoutManager()
        customTextStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: .zero) // Or appropriate size
        layoutManager.addTextContainer(textContainer)
        
        // Important: Set textContainer.width and heightTracksTextView if using .zero size
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = true

        super.init(frame: frame, textContainer: textContainer)
        setupTextView()
    }

    // Override standard initializer to ensure custom storage is used
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        let newTextStorage = BlockBasedTextStorage()
        let layoutManager = NSLayoutManager()
        newTextStorage.addLayoutManager(layoutManager)

        let newTextContainer = textContainer ?? NSTextContainer(size: .zero)
        if textContainer == nil { // If a container wasn't provided, configure our new one
            newTextContainer.widthTracksTextView = true
            newTextContainer.heightTracksTextView = true
        }
        layoutManager.addTextContainer(newTextContainer)
        
        super.init(frame: frame, textContainer: newTextContainer)
        // We call setupTextView AFTER super.init has initialized the textStorage with our container.
        setupTextView()
    }
    
    required init?(coder: NSCoder) {
        // When initializing from a storyboard/nib, a default TextStorage is created.
        // We need to replace it.
        let customTextStorage = BlockBasedTextStorage()
        let layoutManager = NSLayoutManager()
        customTextStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: .zero)
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        // Unfortunately, UITextView's textStorage is get-only publicly after init.
        // The proper way is to ensure the TextContainer passed to super.init(coder:)
        // is already configured with our storage via its layoutManager.
        // This is tricky with NSCoder.
        // A common workaround is to replace the layout manager and its connections.
        
        // For now, let's stick to the programmatic init path and assume this might need more work
        // if storyboard/nib instantiation is critical.
        // Fallback to a basic setup, which might not use BlockBasedTextStorage correctly from Storyboard.
        // Ideally, the app avoids initializing this view from a Storyboard if BlockBasedTextStorage is essential.
        super.init(coder: coder) // This will use a default textStorage
        setupTextView() // Then try to replace (less ideal)

        // Attempt to replace the layout manager and connect new storage
        // This is a more robust approach for NSCoder
        let existingTextContainer = self.textContainer
        
        // Remove existing layout manager from default text storage
        // Ensure layoutManager is not nil before trying to remove it from textStorage.
        // Though, a textContainer on a UITextView should always have a layoutManager.
        if let currentLayoutManager = existingTextContainer.layoutManager {
            self.textStorage.removeLayoutManager(currentLayoutManager)
        }
        
        // Create and connect our custom stack
        let newLayoutManager = NSLayoutManager()
        customTextStorage.addLayoutManager(newLayoutManager)
        newLayoutManager.addTextContainer(existingTextContainer) // Re-use existing container
        
        // The 'else' block has been removed as it was for a nil textContainer, which shouldn't occur.

         // The key is that self.textStorage needs to be our BlockBasedTextStorage.
         // The above attempts to rewire. If the textStorage property could be set, it would be easier.
         // The most reliable way is usually programmatic creation using the init(frame:textContainer:)
         // where the textContainer is already linked to BlockBasedTextStorage.
    }
    
    private func setupTextView() {
        // Setup text view with custom container inset to leave room for calorie display
        backgroundColor = .clear
        font = .systemFont(ofSize: 18)
        textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 90) // Extra right inset for calories
        
        // Ensure layout manager is used for exclusion paths (COMMENTED OUT FOR NOW)
        // layoutManager.allowsNonContiguousLayout = false // Often needed for complex layouts

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
    
    // MARK: - Calorie Marker Insertion - Method Removed
    // func insertCalorieMarker() { ... } // Removed
    
    // MARK: - Image Marker Insertion (Replaces Block Insertion)

    func insertImageMarkerAndText(with mockText: String) {
        // --- LOGIC COMMENTED OUT FOR NOW ---
        /*
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
        */
        print("[DEBUG] insertImageMarkerAndText called, but logic is currently commented out.")
    }
    
    // MARK: - Text Processing
    
    // Handle text changes
    @objc private func textDidChange() {
        // --- DEBUG LOG --- 
        print("[DEBUG] textDidChange called.")

        // Notify about text changes
        onTextChanged?(textStorage.string) // Existing callback, ensure it uses textStorage.string
        
        // Existing paragraph/calorie update
        paragraphs.removeAll()
        calorieLabels.forEach { $0.removeFromSuperview() }
        calorieLabels.removeAll()
        updateParagraphs() // This needs to be aware of the image marker (logic to be adapted)
        
        // Trigger layout update to reposition images/exclusion paths (COMMENTED OUT FOR NOW)
        // setNeedsLayout()
        // layoutIfNeeded() // Force layout calculation immediately if needed
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
        
        self.paragraphs.removeAll() 
        
        // Ensure we are using the textStorage from our BlockBasedTextStorage
        guard let currentTextStorage = self.textStorage as? BlockBasedTextStorage else {
            print("[DEBUG] updateParagraphs: TextStorage is not BlockBasedTextStorage. Aborting.")
            // Potentially handle this more gracefully, e.g., by falling back to default behavior
            // or ensuring this never happens through correct initialization.
            return
        }

        let fullText = currentTextStorage.string
        let nsText = fullText as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        var enumerationIndex = 0 
        
        nsText.enumerateSubstrings(in: fullRange, options: [.byParagraphs, .substringNotRequired]) { _, substringRange, _, _ in
            let currentEnumIndex = enumerationIndex
            enumerationIndex += 1
            
            let paragraphText = nsText.substring(with: substringRange)
            // No longer need to check for calorieMarkerCharacter here for calorie calculation purposes
            // let containsCalorieMarker = paragraphText.contains(self.calorieMarkerCharacter)
            // let textForCalories = paragraphText.replacingOccurrences(of: self.calorieMarkerCharacter, with: "") // Original text is used
            let trimmedTextForCalculation = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines)

            // Determine the block type from textStorage attributes
            var currentBlockType: BlockType = .textBlock // Default
            if substringRange.length > 0 {
                // Get attributes at the start of the paragraph. 
                // Assuming blockType attribute covers the whole paragraph or is consistent at its start.
                let attributes = currentTextStorage.attributes(at: substringRange.location, effectiveRange: nil)
                if let blockTypeRawValue = attributes[.blockType] as? String,
                   let resolvedBlockType = BlockType(rawValue: blockTypeRawValue) {
                    currentBlockType = resolvedBlockType
                }
            }
            
            // Simplified condition: Calculate calories for any non-empty text block.
            // Image placeholders would have their own logic if re-enabled.
            if currentBlockType == .textBlock && !trimmedTextForCalculation.isEmpty {
                let newParagraph = ParagraphInfo(
                    range: substringRange,
                    text: paragraphText, // Store original paragraph text
                    blockType: currentBlockType 
                    // hasCalorieMarker: false (removed from ParagraphInfo)
                )
                self.paragraphs.append(newParagraph)
                let newIndex = self.paragraphs.count - 1
                
                print("[DEBUG] updateParagraphs: Created ParagraphInfo - Index: \(newIndex), Type: \(newParagraph.blockType.rawValue), Text: '\(newParagraph.text.debugDescription)'")
                
                // Calculate calories for this text block
                self.calculateCalories(for: newIndex, text: trimmedTextForCalculation) 

            } else if currentBlockType == .imagePlaceholder {
                // Handle image placeholders (currently no calorie calc for them)
                 let newParagraph = ParagraphInfo(
                    range: substringRange,
                    text: paragraphText, 
                    blockType: currentBlockType
                )
                self.paragraphs.append(newParagraph)
                print("[DEBUG] updateParagraphs: Created Image Placeholder ParagraphInfo - Text: '\(newParagraph.text.debugDescription)'")
            }
            // else: Skip empty paragraphs or other block types not handled for calorie display
        }
        
        updateTotalCalories()
        updateActiveParagraph()
        updateCalorieDisplay() 
    }
    
    // Calculate calories for a paragraph
    private func calculateCalories(for paragraphIndex: Int, text: String) {
        // Skip calculation for empty text
        if text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty { return }
        
        // print("[DEBUG] calculateCalories: Requesting calculation for index \(paragraphIndex), text: \(text.prefix(30))...")

        onNeedCalorieCalculation?(text) { [weak self] calories in
            // print("[DEBUG] calculateCalories CB: Received \(calories) kcal for original index \(paragraphIndex)")
            guard let self = self else {
                 // print("[DEBUG] calculateCalories CB: Self is nil. Bailing.")
                 return
            }
            guard paragraphIndex < self.paragraphs.count else {
                // print("[DEBUG] calculateCalories CB: Index \(paragraphIndex) is out of bounds for current paragraphs count \(self.paragraphs.count). Bailing.")
                return 
            }
            
            var updatedParagraph = self.paragraphs[paragraphIndex]
            // print("[DEBUG] calculateCalories CB: Updating paragraph at index \(paragraphIndex). Current text: \(updatedParagraph.text.prefix(30))... Current calories: \(updatedParagraph.calories ?? -1)")
            updatedParagraph.calories = calories
            self.paragraphs[paragraphIndex] = updatedParagraph
            // print("[DEBUG] calculateCalories CB: Updated paragraph at index \(paragraphIndex) with \(calories) kcal.")
            
            self.scheduleCalorieDisplayUpdate()
        }
    }
    
    // Force recalculation of all paragraphs
    func recalculateAllParagraphs() {
        for (index, paragraph) in paragraphs.enumerated() {
            if paragraph.blockType == .textBlock {
                 let trimmedText = paragraph.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                 if !trimmedText.isEmpty {
                    calculateCalories(for: index, text: trimmedText)
                }
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
        // print("[DEBUG] updateCalorieDisplay: Delegating to TextEditorLayoutManager.")
        
        self.calorieLabels = layoutHelper.layoutCalorieLabels(
            labels: self.calorieLabels, 
            forParagraphs: self.paragraphs,
            inTextView: self,
            withActiveParagraph: self.activeParagraphIndex
        )
        
        // print("[DEBUG] updateCalorieDisplay: Layout manager returned \(self.calorieLabels.count) labels.")
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
        // print("[DEBUG] layoutSubviews called.")
        // updateImagePlaceholderViews() // COMMENTED OUT FOR NOW
        updateCalorieDisplay() // Call this after image layout (or general layout)
    }
    
    private func updateImagePlaceholderViews() {
        // --- LOGIC COMMENTED OUT FOR NOW ---
        /*
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
        
        print("[DEBUG] Found \(markerRanges.count) marker character ranges: \(markerRanges)")

        for range in markerRanges {
            print("[DEBUG] Processing marker at range \(range)")
            
            let layoutManager = self.layoutManager
            let textContainer = self.textContainer
            
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: range.location)
            
            var effectiveRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange)
            print("[DEBUG] Line fragment rect: \(lineRect), Effective range: \(effectiveRange)")
            
            if lineRect.isEmpty || lineRect.isInfinite {
                 print("[DEBUG] Warning: Line fragment rect is invalid. Skipping. Rect: \(lineRect)")
                 continue
            }

            let viewOrigin = CGPoint(x: textContainerInset.left + horizontalPadding,
                                     y: textContainerInset.top + lineRect.minY + verticalPadding)
            let viewFrame = CGRect(origin: viewOrigin, size: placeholderSize)
            print("[DEBUG] Calculated placeholder view frame: \(viewFrame)")
            
            let placeholderContentView = BlockPlaceholderView()
            let hostingController = UIHostingController(rootView: placeholderContentView)
            hostingController.view.frame = viewFrame
            hostingController.view.backgroundColor = .clear
            print("[DEBUG] Hosting controller view frame after setting: \(hostingController.view.frame)")
            
            addSubview(hostingController.view)
            imagePlaceholderViews.append(hostingController.view)
            print("[DEBUG] Added placeholder subview. Current count: \(imagePlaceholderViews.count)")
            print("[DEBUG] Hosting controller view bounds after adding: \(hostingController.view.bounds)")
            
            let exclusionRect = CGRect(x: horizontalPadding,
                                       y: lineRect.minY + verticalPadding,
                                       width: max(1, placeholderSize.width + horizontalPadding),
                                       height: max(1, placeholderSize.height + (verticalPadding * 2)))
            let exclusionPath = UIBezierPath(rect: exclusionRect)
            newExclusionPaths.append(exclusionPath)
            print("[DEBUG] Calculated exclusion rect: \(exclusionRect)")
        }
        
        textContainer.exclusionPaths = newExclusionPaths
        print("[DEBUG] Applied \(newExclusionPaths.count) exclusion paths.")
        if !newExclusionPaths.isEmpty {
            print("[DEBUG] First exclusion path bounds: \(newExclusionPaths.first?.bounds)")
        }
        */
        print("[DEBUG] updateImagePlaceholderViews called, but logic is currently commented out.")
    }
    
    // Clean up
    deinit {
        NotificationCenter.default.removeObserver(self)
        // Clean up hosting controllers if necessary
        // imagePlaceholderViews.forEach { $0.removeFromSuperview() }
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
