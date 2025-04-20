//
//  TextEditorLayoutManager.swift
//  calcalcal
//
//  Created by Artem Savelev on 18/03/2025.
//


//
//  TextEditorLayoutManager.swift
//  calcalcal
//
//  Created for improved layout management
//

import UIKit

class TextEditorLayoutManager {
    // MARK: - Types
    
    /// Configuration for calorie display appearance and positioning
    struct CalorieDisplayConfiguration {
        var font: UIFont = .systemFont(ofSize: 16)
        var textColor: UIColor = .secondaryLabel
        var rightMargin: CGFloat = 16
        var format: (Int) -> String = { "\($0) kcal" }
    }
    
    // MARK: - Properties
    
    var calorieConfig: CalorieDisplayConfiguration
    
    // MARK: - Initialization
    
    init(calorieConfig: CalorieDisplayConfiguration = CalorieDisplayConfiguration()) {
        self.calorieConfig = calorieConfig
    }
    
    // MARK: - Public Methods
    
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
        
        // --- DEBUG LOG ---
        print("[DEBUG] LayoutMgr: layoutCalorieLabels called for \(paragraphs.count) paragraphs.")
        
        // Create new array for updated labels
        var updatedLabels: [UILabel] = []
        
        // Process each paragraph
        for (index, paragraph) in paragraphs.enumerated() {
            // --- DEBUG LOG ---
            // print("[DEBUG] LayoutMgr: Processing paragraph \(index), Range: \(paragraph.range)")
            
            // Skip paragraphs without calories or empty paragraphs
            if let calories = paragraph.calories,
               !paragraph.isEmpty {
                
                // --- DEBUG LOG ---
                print("[DEBUG] LayoutMgr: Paragraph \(index) HAS calories (\(calories)). Text: \(paragraph.text.prefix(30))...")
                
                // Create and configure label
                let label = UILabel()
                label.text = calorieConfig.format(calories)
                label.font = calorieConfig.font
                label.textColor = calorieConfig.textColor
                label.sizeToFit()
                
                // Get paragraph position
                let paragraphRect = self.paragraphRect(for: paragraph, in: textView)
                // --- DEBUG LOG (moved from paragraphRect) ---
                print("[DEBUG] LayoutMgr: Calculated paragraphRect for index \(index): \(paragraphRect)")
                
                // Check for invalid rects
                if paragraphRect.isNull || paragraphRect.isInfinite || paragraphRect.isEmpty {
                    print("[DEBUG] LayoutMgr: Invalid paragraphRect for index \(index). Skipping label.")
                    continue
                }
                
                // Calculate x position with appropriate margin
                let xPosition = textView.bounds.width - label.bounds.width - calorieConfig.rightMargin
                
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
        guard let text = textView.text, !text.isEmpty, paragraph.range.length > 0, 
              (paragraph.range.location + paragraph.range.length) <= textView.textStorage.length else {
            // --- DEBUG LOG ---
            // print("[DEBUG] LayoutMgr - paragraphRect: Bailing early due to empty text or invalid range \(paragraph.range)")
            return .null // Return null rect for invalid input
        }
        
        // Get layout manager from text view
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        
        // Ensure layout is up-to-date before calculating
        // layoutManager.ensureLayout(for: textContainer) // Can sometimes help, but use cautiously
        
        // Convert character range to glyph range
        let glyphRange = layoutManager.glyphRange(forCharacterRange: paragraph.range, 
                                                actualCharacterRange: nil)
                                                
        // --- DEBUG LOG ---
        // print("[DEBUG] LayoutMgr - paragraphRect: Index \(index), GlyphRange: \(glyphRange)") // Need index here if logging
        
        // Find the bounding rect for the glyphs
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // Adjust for text container insets
        rect.origin.x += textView.textContainerInset.left
        rect.origin.y += textView.textContainerInset.top
        
        // --- DEBUG LOG ---
        // print("[DEBUG] LayoutMgr - paragraphRect: Index \(index), Final Rect: \(rect)") // Need index here if logging
        
        return rect
    }
}