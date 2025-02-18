import SwiftUI
import UIKit

class TextLineManager: ObservableObject {
    @Published private(set) var lineData: [LineData] = []
    var onDataUpdated: (([LineData]) -> Void)? = nil
    
    func updateLineData(from textView: UITextView) {
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        
        var newLineData: [LineData] = []
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        
        var lineIndex = 0
        
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
        if textView.text.isEmpty {
            newLineData = [LineData(
                id: UUID(),
                text: "",
                lineRect: CGRect(x: 0, y: 0, width: textView.bounds.width - 100, height: 22),
                lineIndex: 0,
                metadata: [:]
            )]
        }
        
        // Update on main thread
        DispatchQueue.main.async {
            self.lineData = newLineData
            self.onDataUpdated?(newLineData)
        }
    }
    
    func addMetadata(for lineIndex: Int, key: String, value: AnyHashable) {
        guard lineIndex < lineData.count else { return }
        
        var updatedLines = lineData
        var metadata = updatedLines[lineIndex].metadata
        metadata[key] = value
        updatedLines[lineIndex].metadata = metadata
        
        lineData = updatedLines
    }
}
