import SwiftUI
import UIKit

class TextLineManager: ObservableObject {
    @Published private(set) var lineData: [LineData] = []
    @Published private(set) var paragraphs: [ParagraphData] = []
    var onDataUpdated: (([ParagraphData]) -> Void)? = nil
    
    // Add this structure to represent paragraphs
    struct ParagraphData: Identifiable, Equatable {
        let id: UUID
        let lines: [LineData]
        var text: String
        var startLineIndex: Int
        var endLineIndex: Int
        var metadata: [String: AnyHashable]
        
        var isEmpty: Bool {
            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        static func == (lhs: ParagraphData, rhs: ParagraphData) -> Bool {
            return lhs.id == rhs.id &&
                   lhs.startLineIndex == rhs.startLineIndex &&
                   lhs.endLineIndex == rhs.endLineIndex &&
                   lhs.text == rhs.text
        }
    }
    
    func updateLineData(from textView: UITextView) {
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        
        var newLineData: [LineData] = []
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        
        var lineIndex = 0
        
        // Get layout for each line fragment
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { (rect, usedRect, textContainer, range, _) in
            let lineRange = layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: nil)
            
            // Skip if text is empty
            guard textView.text.count > 0 else { return }
            
            let lineText = (textView.text as NSString).substring(with: NSRange(
                location: lineRange.location,
                length: lineRange.length
            ))
            
            let adjustedRect = CGRect(
                x: rect.minX,
                y: rect.minY + textView.textContainerInset.top,
                width: rect.width,
                height: rect.height
            )
            
            // Preserve existing metadata if available
            var metadata: [String: AnyHashable] = [:]
            if lineIndex < self.lineData.count {
                metadata = self.lineData[lineIndex].metadata
            }
            
            let newLine = LineData(
                id: UUID(),
                text: lineText,
                lineRect: adjustedRect,
                lineIndex: lineIndex,
                metadata: metadata
            )
            
            newLineData.append(newLine)
            lineIndex += 1
        }
        
        // Handle empty text case
        if textView.text.isEmpty || newLineData.isEmpty {
            newLineData = [LineData(
                id: UUID(),
                text: "",
                lineRect: CGRect(x: 0, y: 0, width: textView.bounds.width - 100, height: 22),
                lineIndex: 0,
                metadata: [:]
            )]
        }
        
        // Group lines into paragraphs
        let paragraphs = groupLinesIntoParagraphs(newLineData, text: textView.text)
        
        // Update on main thread
        DispatchQueue.main.async {
            self.lineData = newLineData
            self.paragraphs = paragraphs
            self.onDataUpdated?(paragraphs)
        }
    }
    
    // Group lines into logical paragraphs based on newlines
    private func groupLinesIntoParagraphs(_ lines: [LineData], text: String) -> [ParagraphData] {
        let textComponents = text.components(separatedBy: "\n")
        var paragraphs: [ParagraphData] = []
        
        var currentParagraphLines: [LineData] = []
        var startLineIndex = 0
        var currentTextIndex = 0
        
        for i in 0..<lines.count {
            let line = lines[i]
            
            // Check if this line is a paragraph boundary
            let isEndOfParagraph = line.text.hasSuffix("\n") || i == lines.count - 1
            currentParagraphLines.append(line)
            
            if isEndOfParagraph {
                let paragraphText = currentTextIndex < textComponents.count 
                    ? textComponents[currentTextIndex] 
                    : ""
                
                let paragraph = ParagraphData(
                    id: UUID(),
                    lines: currentParagraphLines,
                    text: paragraphText,
                    startLineIndex: startLineIndex,
                    endLineIndex: i,
                    metadata: [:]
                )
                
                paragraphs.append(paragraph)
                
                // Reset for next paragraph
                currentParagraphLines = []
                startLineIndex = i + 1
                currentTextIndex += 1
            }
        }
        
        // Ensure we have at least one paragraph
        if paragraphs.isEmpty {
            paragraphs = [ParagraphData(
                id: UUID(),
                lines: lines,
                text: text,
                startLineIndex: 0,
                endLineIndex: lines.count - 1,
                metadata: [:]
            )]
        }
        
        return paragraphs
    }
    
    func addParagraphMetadata(for index: Int, key: String, value: AnyHashable) {
        guard index < paragraphs.count else { return }
        
        var updatedParagraphs = paragraphs
        var metadata = updatedParagraphs[index].metadata
        metadata[key] = value
        updatedParagraphs[index].metadata = metadata
        
        paragraphs = updatedParagraphs
    }
}