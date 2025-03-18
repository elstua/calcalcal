//
//  TextEditorLayoutManager.swift
//  calcalcal
//
//  Created for improved layout management
//

import UIKit

class TextEditorLayoutManager {
    // MARK: - Types
    
    /// Configuration for button appearance and positioning
    struct ButtonConfiguration {
        var buttonSize: CGSize = CGSize(width: 26, height: 26)
        var rightMargin: CGFloat = 16
        var buttonImage: UIImage? = UIImage(systemName: "plus.circle.fill")
        var tintColor: UIColor = .systemOrange
    }
    
    /// Configuration for calorie display appearance and positioning
    struct CalorieDisplayConfiguration {
        var font: UIFont = .systemFont(ofSize: 16)
        var textColor: UIColor = .secondaryLabel
        var rightMargin: CGFloat = 16
        var activeRightMargin: CGFloat = 46 // Extra space when active to accommodate button
        var format: (Int) -> String = { "\($0) kcal" }
    }
    
    // MARK: - Properties
    
    var buttonConfig: ButtonConfiguration
    var calorieConfig: CalorieDisplayConfiguration
    
    // MARK: - Initialization
    
    init(buttonConfig: ButtonConfiguration = ButtonConfiguration(),
         calorieConfig: CalorieDisplayConfiguration = CalorieDisplayConfiguration()) {
        self.buttonConfig = buttonConfig
        self.calorieConfig = calorieConfig
    }
    
    // MARK: - Public Methods
    
    /// Positions the action button based on the active paragraph and cursor state
    /// - Parameters:
    ///   - buttonView: The button view to position
    ///   - paragraph: The active paragraph or nil if no paragraph is active
    ///   - textView: The text view containing the paragraphs
    ///   - cursorPosition: The current cursor position
    ///   - hasImplicitEmptyLine: Whether there's an implicit empty line at the end
    func layoutButton(buttonView: UIButton, 
                     forParagraph paragraph: ParagraphInfo?, 
                     inTextView textView: UITextView,
                     withCursorPosition cursorPosition: Int,
                     hasImplicitEmptyLine: Bool) {
        
        // Configure button appearance
        buttonView.setImage(buttonConfig.buttonImage, for: .normal)
        buttonView.tintColor = buttonConfig.tintColor
        
        // Set button size
        buttonView.frame.size = buttonConfig.buttonSize
        
        let bounds = textView.bounds
        let insets = textView.textContainerInset
        
        // Empty text case
        if (textView.text ?? "").isEmpty {
            buttonView.frame.origin = CGPoint(
                x: bounds.width - buttonConfig.buttonSize.width - buttonConfig.rightMargin,
                y: insets.top
            )
            buttonView.isHidden = false
            return
        }
        
        // Active paragraph case
        if let paragraph = paragraph {
            let paragraphRect = paragraphRect(for: paragraph, in: textView)
            
            buttonView.frame.origin = CGPoint(
                x: bounds.width - buttonConfig.buttonSize.width - buttonConfig.rightMargin,
                y: paragraphRect.midY - (buttonConfig.buttonSize.height / 2)
            )
            buttonView.isHidden = false
            
            // Special case: cursor at end of last paragraph
            if isAtEndOfParagraph(cursorPosition: cursorPosition, paragraph: paragraph) && 
               paragraph.isLastParagraph && hasImplicitEmptyLine {
                
                let implicitLinePosition = positionForImplicitLine(after: paragraph, in: textView)
                buttonView.frame.origin = CGPoint(
                    x: bounds.width - buttonConfig.buttonSize.width - buttonConfig.rightMargin,
                    y: implicitLinePosition.y
                )
            }
            
            return
        }
        
        // Implicit empty line case (cursor at end of text)
        if hasImplicitEmptyLine {
            let implicitLinePosition = positionForEndOfText(textView: textView)
            
            buttonView.frame.origin = CGPoint(
                x: bounds.width - buttonConfig.buttonSize.width - buttonConfig.rightMargin,
                y: implicitLinePosition.y
            )
            buttonView.isHidden = false
            return
        }
        
        // Default case (no active paragraph, no implicit line)
        buttonView.isHidden = true
    }
    
    /// Positions calorie labels for paragraphs
    /// - Parameters:
    ///   - labels: Array of existing labels to update
    ///   - paragraphs: Array of paragraph information
    ///   - textView: The text view containing the paragraphs
    ///   - activeParagraphIndex: Index of the active paragraph
    /// - Returns: Array of updated labels
    func layoutCalorieLabels(labels: [UILabel], 
                          forParagraphs paragraphs: [ParagraphInfo],
                          inTextView textView: UITextView, 
                          withActiveParagraph activeParagraphIndex: Int?) -> [UILabel] {
        
        // Remove existing labels
        labels.forEach { $0.removeFromSuperview() }
        
        // Create new array for updated labels
        var updatedLabels: [UILabel] = []
        
        // Process each paragraph
        for (index, paragraph) in paragraphs.enumerated() {
            // Skip paragraphs without calories or empty paragraphs
            if let calories = paragraph.calories,
               !paragraph.isEmpty {
                
                // Create and configure label
                let label = UILabel()
                label.text = calorieConfig.format(calories)
                label.font = calorieConfig.font
                label.textColor = calorieConfig.textColor
                label.sizeToFit()
                
                // Determine if this is the active paragraph
                let isActive = index == activeParagraphIndex
                
                // Get paragraph position
                let paragraphRect = self.paragraphRect(for: paragraph, in: textView)
                
                // Calculate x position with appropriate margin
                let xOffset = isActive ? calorieConfig.activeRightMargin : calorieConfig.rightMargin
                let xPosition = textView.bounds.width - label.bounds.width - xOffset
                
                // Position label
                label.frame = CGRect(
                    x: xPosition,
                    y: paragraphRect.midY - (label.bounds.height / 2),
                    width: label.bounds.width,
                    height: label.bounds.height
                )
                
                // Add to text view and track
                textView.addSubview(label)
                updatedLabels.append(label)
            }
        }
        
        return updatedLabels
    }
    
    // MARK: - Private Helper Methods
    
    /// Calculates the rectangle for a paragraph in the text view
    /// - Parameters:
    ///   - paragraph: The paragraph to get the rect for
    ///   - textView: The text view containing the paragraph
    /// - Returns: Rectangle for the paragraph
    private func paragraphRect(for paragraph: ParagraphInfo, in textView: UITextView) -> CGRect {
        // Handle empty text or empty paragraph
        if (textView.text ?? "").isEmpty || paragraph.range.length == 0 {
            return CGRect(
                x: 0,
                y: textView.textContainerInset.top,
                width: textView.bounds.width,
                height: textView.font?.lineHeight ?? 20
            )
        }
        
        // Get layout manager from text view
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        
        // Convert character range to glyph range
        let glyphRange = layoutManager.glyphRange(forCharacterRange: paragraph.range, 
                                                actualCharacterRange: nil)
        
        // Find the bounding rect for the glyphs
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // Adjust for text container insets
        rect.origin.x += textView.textContainerInset.left
        rect.origin.y += textView.textContainerInset.top
        
        return rect
    }
    
    /// Determines if cursor is at the end of a paragraph
    /// - Parameters:
    ///   - cursorPosition: The current cursor position
    ///   - paragraph: The paragraph to check
    /// - Returns: True if cursor is at the end of the paragraph
    private func isAtEndOfParagraph(cursorPosition: Int, paragraph: ParagraphInfo) -> Bool {
        return cursorPosition == paragraph.range.location + paragraph.range.length
    }
    
    /// Calculates position for an implicit line after a paragraph
    /// - Parameters:
    ///   - paragraph: The paragraph to position after
    ///   - textView: The text view
    /// - Returns: Y position for the implicit line
    private func positionForImplicitLine(after paragraph: ParagraphInfo, in textView: UITextView) -> CGPoint {
        let paragraphRect = self.paragraphRect(for: paragraph, in: textView)
        let lineHeight = textView.font?.lineHeight ?? 20
        
        return CGPoint(
            x: textView.textContainerInset.left,
            y: paragraphRect.maxY + (lineHeight * 0.2) // Slight offset for visual spacing
        )
    }
    
    /// Calculates position for the end of text (for implicit new line)
    /// - Parameter textView: The text view
    /// - Returns: Position for end of text
    private func positionForEndOfText(textView: UITextView) -> CGPoint {
        // Empty text case
        if (textView.text ?? "").isEmpty {
            return CGPoint(x: textView.textContainerInset.left, y: textView.textContainerInset.top)
        }
        
        // Get cursor position at end of text
        let endPosition = textView.text.count
        
        if let position = textView.position(from: textView.beginningOfDocument, offset: endPosition) {
            let caretRect = textView.caretRect(for: position)
            return caretRect.origin
        }
        
        // Fallback
        return CGPoint(x: textView.textContainerInset.left, y: textView.textContainerInset.top)
    }
}