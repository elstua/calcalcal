import UIKit

// MARK: - Drawing and Rendering Extension

extension UnifiedTextView {
    
    // MARK: - Drawing
    
    /// Draw calorie labels for every block for debugging
    internal func drawCalorieLabels(in rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        unifiedContentStorage.enumerateParagraphs { paragraphRange, _ in
            // Get the glyph range for the paragraph
            let glyphRange = self.layoutManager.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)
            var lastLineRect: CGRect?
            self.layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { (lineRect, usedRect, textContainer, glyphRange, stop) in
                lastLineRect = lineRect
            }
            // Only proceed if we have a last line rect
            guard let lastLineRect = lastLineRect else { return }
            // Calculate the right 15% area for the calorie label
            let totalWidth = self.textContainer.size.width
            let calorieAreaWidth = totalWidth * 0.15
            let textAreaWidth = totalWidth * 0.85
            // Convert to view coordinates
            var calorieLabelRect = lastLineRect
            calorieLabelRect.origin.x += self.textContainerInset.left + textAreaWidth
            calorieLabelRect.origin.y += self.textContainerInset.top - 4
            calorieLabelRect.size.width = calorieAreaWidth
            // Only draw if the calorie label rect intersects the visible rect
            if calorieLabelRect.intersects(rect) {
                // Always draw a random calorie label for debug
                let randomCalories = Int.random(in: 50...600)
                let calories = "\(randomCalories) kcal"
                self.unifiedLayoutManager.drawCalorieLabel(calories, in: calorieLabelRect, context: context)
            }
        }
    }
} 
