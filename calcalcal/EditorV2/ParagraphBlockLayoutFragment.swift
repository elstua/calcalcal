import UIKit

@available(iOS 16.0, *)
final class ParagraphBlockLayoutFragment: NSTextLayoutFragment {
    var blockMetadata: BlockMetadata?
    
    override func draw(at point: CGPoint, in context: CGContext) {
        if let style = blockMetadata?.style {
            let backgroundRect = layoutFragmentFrame
                .offsetBy(dx: point.x, dy: point.y)
                .expanded(by: style.contentInsets)
            context.saveGState()
            context.setFillColor(style.backgroundColor.cgColor)
            let path = UIBezierPath(roundedRect: backgroundRect, cornerRadius: style.cornerRadius)
            context.addPath(path.cgPath)
            context.fillPath()
            context.restoreGState()
        }
        
        super.draw(at: point, in: context)
    }
}

// MARK: - Helpers

@available(iOS 16.0, *)
private extension CGRect {
    func expanded(by insets: NSDirectionalEdgeInsets) -> CGRect {
        var rect = self
        rect.origin.x -= insets.leading
        rect.origin.y -= insets.top
        rect.size.width += insets.leading + insets.trailing
        rect.size.height += insets.top + insets.bottom
        return rect
    }
}


