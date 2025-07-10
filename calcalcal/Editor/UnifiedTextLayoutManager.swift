import UIKit

/// Custom layout manager that handles block spacing and custom layouts
class UnifiedTextLayoutManager: NSObject {
    
    // MARK: - Configuration
    
    /// Default spacing between blocks
    var defaultBlockSpacing: CGFloat = 100.0
    
    /// Padding for calorie labels
    var calorieLabelPadding: CGFloat = 8.0
    
    // MARK: - Block Layout Helpers
    
    /// Calculate additional spacing for a block
    func spacingForBlock(with metadata: UnifiedTextContentStorage.BlockMetadata?) -> CGFloat {
        return metadata?.blockSpacing ?? defaultBlockSpacing
    }
    
    /// Draw calorie label for a block
    func drawCalorieLabel(_ calories: String, in rect: CGRect, context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor.systemGray
        ]
        
        let attributedString = NSAttributedString(string: calories, attributes: attributes)
        let size = attributedString.size()
        
        // Position at the right edge of the rect
        let labelPoint = CGPoint(
            x: rect.maxX - size.width - calorieLabelPadding,
            y: rect.minY + 4
        )
        
        // Draw the calorie label
        attributedString.draw(at: labelPoint)
    }
} 
