import UIKit

@available(iOS 16.0, *)
final class ImageBlockLayoutFragment: NSTextLayoutFragment {
    var blockMetadata: BlockMetadata?
    private let fallbackHeight: CGFloat = 120
    private let imageSize = CGSize(width: 48, height: 72)
    private let interItemSpacing: CGFloat = 12
    
    override func draw(at point: CGPoint, in context: CGContext) {
        guard let metadata = blockMetadata else {
            super.draw(at: point, in: context)
            return
        }
        
        let style = metadata.style
        let fragmentRect = layoutFragmentFrame.offsetBy(dx: point.x, dy: point.y)
        let backgroundRect = fragmentRect.expanded(by: style.contentInsets)
        
        context.saveGState()
        context.setFillColor(style.backgroundColor.cgColor)
        UIBezierPath(roundedRect: backgroundRect, cornerRadius: style.cornerRadius).fill()
        
        let contentRect = backgroundRect.inset(by: UIEdgeInsets(
            top: style.contentInsets.top,
            left: style.contentInsets.leading,
            bottom: style.contentInsets.bottom,
            right: style.contentInsets.trailing
        ))
        
        let imageRect = CGRect(
            x: contentRect.minX,
            y: contentRect.midY - imageSize.height / 2,
            width: imageSize.width,
            height: imageSize.height
        )
        
        context.setFillColor(UIColor.systemGray5.cgColor)
        let imagePath = UIBezierPath(roundedRect: imageRect, cornerRadius: 12)
        context.addPath(imagePath.cgPath)
        context.fillPath()
        
        if let symbol = UIImage(systemName: "photo.fill") {
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            let rendered = symbol.applyingSymbolConfiguration(symbolConfig) ?? symbol
            let symbolSize = rendered.size
            let symbolOrigin = CGPoint(
                x: imageRect.midX - symbolSize.width / 2,
                y: imageRect.midY - symbolSize.height / 2
            )
            rendered.draw(in: CGRect(origin: symbolOrigin, size: symbolSize))
        }
        
        let textRect = CGRect(
            x: imageRect.maxX + interItemSpacing,
            y: contentRect.minY,
            width: max(0, contentRect.maxX - imageRect.maxX - interItemSpacing),
            height: contentRect.height
        )
        
        if let caption = captionText(from: metadata) {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            paragraphStyle.minimumLineHeight = 20
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle
            ]
            let attributedCaption = NSAttributedString(string: caption, attributes: attributes)
            attributedCaption.draw(in: textRect)
        }
        
        context.restoreGState()
    }
    
    private func captionText(from metadata: BlockMetadata) -> String? {
        if case let .image(_, _, caption) = metadata.content {
            if let caption, !caption.isEmpty {
                return caption
            }
        }
        return "Image block"
    }
}

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

