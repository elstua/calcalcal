//
//  CursorPositionManager.swift
//  calcalcal
//
//  Created by Artem Savelev on 18/03/2025.
//


//
//  CursorPositionManager.swift
//  calcalcal
//
//  Created for improved cursor tracking
//

import UIKit

class CursorPositionManager {
    // MARK: - Properties
    
    // Callback when cursor position changes
    var onCursorPositionChanged: ((Int, Int?, Bool) -> Void)?
    
    // MARK: - Public Methods
    
    /// Updates cursor position and determines active paragraph
    /// - Parameters:
    ///   - position: The current cursor position in the text
    ///   - text: The complete text content
    ///   - paragraphs: Array of paragraph information
    func updateCursorPosition(position: Int, inText text: String, withParagraphs paragraphs: [ParagraphInfo]) {
        // Determine which paragraph is active based on cursor position
        let activeParagraphIndex = determineActiveParagraph(cursorPosition: position, 
                                                          text: text, 
                                                          paragraphs: paragraphs)
        
        // Check if cursor is at the end of the text (potential new line position)
        let hasImplicitEmptyLine = position == text.count && 
            (activeParagraphIndex == nil || activeParagraphIndex == paragraphs.count - 1)
        
        // Notify listeners
        onCursorPositionChanged?(position, activeParagraphIndex, hasImplicitEmptyLine)
    }
    
    // MARK: - Private Methods
    
    /// Determines which paragraph contains the cursor
    /// - Parameters:
    ///   - cursorPosition: The current cursor position
    ///   - text: The complete text content
    ///   - paragraphs: Array of paragraph information
    /// - Returns: Index of the active paragraph, or nil if no paragraph contains the cursor
    private func determineActiveParagraph(cursorPosition: Int, text: String, paragraphs: [ParagraphInfo]) -> Int? {
        // Handle empty text case
        if text.isEmpty {
            return nil // No active paragraph in empty text
        }
        
        // Find which paragraph contains the cursor
        let activeIndex = paragraphs.firstIndex { paragraph in
            let range = paragraph.range
            return cursorPosition >= range.location && cursorPosition <= range.location + range.length
        }
        
        return activeIndex
    }
    
    /// Determines if cursor is at a position that would create a new paragraph
    /// - Parameters:
    ///   - cursorPosition: The current cursor position
    ///   - text: The complete text content
    ///   - paragraphs: Array of paragraph information
    /// - Returns: True if the cursor position indicates a new paragraph would be created
    func isAtNewParagraphPosition(cursorPosition: Int, text: String, paragraphs: [ParagraphInfo]) -> Bool {
        // If cursor is at the very end of text, it could indicate a new paragraph
        if cursorPosition == text.count {
            return true
        }
        
        // If cursor is at the beginning of a paragraph after a newline
        if let activeIndex = determineActiveParagraph(cursorPosition: cursorPosition, text: text, paragraphs: paragraphs),
           let paragraph = paragraphs[safe: activeIndex] {
            
            // If at the exact start of a paragraph (except the first one)
            if cursorPosition == paragraph.range.location && activeIndex > 0 {
                // Check if previous paragraph ends with newline
                let previousParagraph = paragraphs[activeIndex - 1]
                let previousText = (text as NSString).substring(with: previousParagraph.range)
                return previousText.hasSuffix("\n")
            }
        }
        
        return false
    }
}

// Safe array access extension
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}