import UIKit

class ImageTextBlockLayout: BlockLayoutProviding {
    func exclusionPaths(for paragraphRange: NSRange, in view: UnifiedTextView, metadata: UnifiedTextContentStorage.BlockMetadata) -> [UIBezierPath] {
        let totalWidth = view.textContainer.size.width
        let imageWidth = totalWidth * 0.30
        let remainingWidth = totalWidth - imageWidth
        let calorieAreaWidth = remainingWidth * 0.30
        let boundingRect = view.boundingRect(for: paragraphRange)
        let blockHeight = max(100, boundingRect.height)
        let imageFrame = CGRect(
            x: 0,
            y: boundingRect.origin.y,
            width: imageWidth,
            height: blockHeight
        )
        let calorieExclusionRect = CGRect(
            x: imageWidth + (remainingWidth - calorieAreaWidth),
            y: boundingRect.origin.y,
            width: calorieAreaWidth,
            height: blockHeight
        )
        return [UIBezierPath(rect: imageFrame), UIBezierPath(rect: calorieExclusionRect)]
    }
    
    func calorieLabelFrame(for paragraphRange: NSRange, in view: UnifiedTextView, metadata: UnifiedTextContentStorage.BlockMetadata, blockFrame: CGRect) -> CGRect? {
        let totalWidth = view.bounds.width - view.textContainerInset.left - view.textContainerInset.right
        let imageWidth = totalWidth * 0.30
        let remainingWidth = totalWidth - imageWidth
        let calorieAreaWidth = remainingWidth * 0.30
        let calorieLabelX = view.bounds.width - view.textContainerInset.right - calorieAreaWidth - blockFrame.origin.x

        if let lastLineRect = view.lastLineRect(for: paragraphRange) {
            let calorieLabelY = lastLineRect.origin.y - blockFrame.origin.y
            let calorieLabelHeight = lastLineRect.height
            return CGRect(x: calorieLabelX, y: calorieLabelY, width: calorieAreaWidth, height: calorieLabelHeight)
        } else {
            return CGRect(x: calorieLabelX, y: 0, width: calorieAreaWidth, height: 24)
        }
    }
    
    func textAreaWidth(in view: UnifiedTextView, metadata: UnifiedTextContentStorage.BlockMetadata) -> CGFloat {
        let totalWidth = view.textContainer.size.width
        let imageWidth = totalWidth * 0.30
        let remainingWidth = totalWidth - imageWidth
        let calorieAreaWidth = remainingWidth * 0.30
        return remainingWidth - calorieAreaWidth - view.textContainer.lineFragmentPadding * 2
    }
} 