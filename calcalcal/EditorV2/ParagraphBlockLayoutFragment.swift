import UIKit

class ParagraphBlockLayoutFragment: NSTextLayoutFragment {
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

final class ImageBlockLayoutFragment: ParagraphBlockLayoutFragment {
    // For now this shares the same background behavior as text paragraphs.
    // We keep a separate subclass so we can later customize image-specific
    // chrome (e.g. using ImageComponent metrics, overlays, focus state).
}

// MARK: - Helpers

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


