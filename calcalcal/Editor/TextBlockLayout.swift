import UIKit

class TextBlockLayout: BlockLayoutProviding {
    func exclusionPaths(for paragraphRange: NSRange, in view: UnifiedTextView, metadata: UnifiedTextContentStorage.BlockMetadata) -> [UIBezierPath] {
        let totalWidth = view.textContainer.size.width
        let calorieAreaWidth = totalWidth * 0.20
        let exclusionRect = CGRect(
            x: totalWidth - calorieAreaWidth,
            y: 0,
            width: calorieAreaWidth,
            height: view.bounds.height
        )
        return [UIBezierPath(rect: exclusionRect)]
    }
    
    func calorieLabelFrame(for paragraphRange: NSRange, in view: UnifiedTextView, metadata: UnifiedTextContentStorage.BlockMetadata, blockFrame: CGRect) -> CGRect? {
        let totalWidth = view.bounds.width - view.textContainerInset.left - view.textContainerInset.right
        let calorieAreaWidth = totalWidth * 0.20
        let textAreaRight = view.bounds.width - view.textContainerInset.right - view.textContainer.lineFragmentPadding
        let calorieLabelX = textAreaRight - calorieAreaWidth - blockFrame.origin.x
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
        let calorieAreaWidth = totalWidth * 0.20
        return totalWidth - calorieAreaWidth - view.textContainer.lineFragmentPadding * 2
    }
} 