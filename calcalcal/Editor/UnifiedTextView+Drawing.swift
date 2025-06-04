import UIKit

// MARK: - Drawing and Rendering Extension

extension UnifiedTextView {
    
    // MARK: - Drawing
    
    /// Draw calorie labels for blocks that have them
    internal func drawCalorieLabels(in rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Draw calorie labels for blocks that have them
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard let metadata = metadata,
                  let calories = metadata.calorieData else { return }
            
            // Get the frame for this paragraph using compatibility method
            let boundingRect = self.boundingRect(for: paragraphRange)
            
            // Convert from text container coordinates to view coordinates
            var blockFrame = boundingRect
            blockFrame.origin.x += self.textContainerInset.left
            blockFrame.origin.y += self.textContainerInset.top
            blockFrame.size.width = self.bounds.width - self.textContainerInset.left - self.textContainerInset.right
            
            // Only draw if the block frame intersects with the visible rect
            if blockFrame.intersects(rect) {
                // Draw calorie label
                self.unifiedLayoutManager.drawCalorieLabel(calories, in: blockFrame, context: context)
            }
        }
    }
} 