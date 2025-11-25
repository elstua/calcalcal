import UIKit

class ParagraphBlockLayoutFragment: NSTextLayoutFragment {
    var blockMetadata: BlockMetadata?
    
    /// Override point for subclasses to compute custom background rect.
    /// Default implementation uses layoutFragmentFrame expanded by content insets.
    func backgroundRect(at point: CGPoint, style: BlockStyle) -> CGRect {
        let fragmentFrame = layoutFragmentFrame
        return CGRect(
            x: point.x - style.contentInsets.leading,
            y: point.y - style.contentInsets.top,
            width: fragmentFrame.width + style.contentInsets.leading + style.contentInsets.trailing,
            height: fragmentFrame.height + style.contentInsets.top + style.contentInsets.bottom
        )
    }
    
    override func draw(at point: CGPoint, in context: CGContext) {
        // Draw block background before text content
        if let style = blockMetadata?.style {
            let bgRect = backgroundRect(at: point, style: style)
            
            context.saveGState()
            context.setFillColor(style.backgroundColor.cgColor)
            let path = UIBezierPath(roundedRect: bgRect, cornerRadius: style.cornerRadius)
            context.addPath(path.cgPath)
            context.fillPath()
            context.restoreGState()
        }
        
        super.draw(at: point, in: context)
    }
}

final class ImageBlockLayoutFragment: ParagraphBlockLayoutFragment {
    /// Image blocks extend to the left edge to include the image overlay area.
    override func backgroundRect(at point: CGPoint, style: BlockStyle) -> CGRect {
        let fragmentFrame = layoutFragmentFrame
        let imageAreaWidth: CGFloat = 72
        return CGRect(
            x: point.x - imageAreaWidth,
            y: point.y - style.contentInsets.top,
            width: fragmentFrame.width + imageAreaWidth + style.contentInsets.trailing,
            height: fragmentFrame.height + style.contentInsets.top + style.contentInsets.bottom
        )
    }
}


