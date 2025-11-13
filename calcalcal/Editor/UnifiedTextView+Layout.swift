import UIKit
#if canImport(SwiftUI)
import SwiftUI
#endif


// MARK: - Layout Management Extension

extension UnifiedTextView {
    
    // MARK: - TextKit Compatibility Helper
    
    /// Get bounding rect for character range using proper text measurement
    internal func boundingRect(for characterRange: NSRange) -> CGRect {
        // Ensure the range is valid
        guard characterRange.location < textStorage.length else {
            return CGRect.zero
        }
        
        // Get the actual paragraph text for this range
        let string = textStorage.string as NSString
        let paragraphText = string.substring(with: characterRange)
        
        // Use TextKit 1 for accurate measurements when we need precise positioning
        // This is necessary for proper block positioning and sizing
        let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // If TextKit 1 gives us a valid rect, use it
        if !boundingRect.isEmpty {
            return boundingRect
        }
        
        // Fallback to manual calculation if TextKit 1 fails
        let font = self.font ?? UIFont.systemFont(ofSize: 16)
        let lineHeight = font.lineHeight
        
        // Calculate the actual number of lines this paragraph will take
        let containerWidth = textContainer.size.width - textContainer.lineFragmentPadding * 2
        
        // Create a temporary text storage to measure the paragraph
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: self.textColor ?? UIColor.label
        ]
        
        let attributedParagraph = NSAttributedString(string: paragraphText, attributes: attributes)
        
        // Calculate the height needed for this text
        let constraintSize = CGSize(width: containerWidth, height: CGFloat.greatestFiniteMagnitude)
        let boundingSize = attributedParagraph.boundingRect(
            with: constraintSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        
        // Calculate Y position by measuring all text before this range
        let textBeforeRange = string.substring(to: characterRange.location)
        let attributedTextBefore = NSAttributedString(string: textBeforeRange, attributes: attributes)
        let heightBefore = attributedTextBefore.boundingRect(
            with: constraintSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size.height
        
        return CGRect(
            x: 0,
            y: heightBefore,
            width: containerWidth,
            height: max(boundingSize.height, lineHeight) // Ensure minimum height
        )
    }
    
    /// Invalidate layout for character range using appropriate API
    private func invalidateLayout(for characterRange: NSRange) {
        // For most cases, we can simply trigger a redraw without accessing layoutManager
        setNeedsDisplay()
        setNeedsLayout()
    }
    
    // MARK: - Exclusion Path Management
    
    /// Update exclusion paths for image-text blocks
    internal func updateExclusionPaths() {
        var exclusionPaths: [UIBezierPath] = []
        let string = textStorage.string as NSString
        guard string.length > 0 else {
            textContainer.exclusionPaths = []
            return
        }
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard let metadata = metadata, paragraphRange.location < string.length, NSMaxRange(paragraphRange) <= string.length else { return }
            let paragraphText = string.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraphText.isEmpty else { return }
            if metadata.blockType == .imageText {
                let provider = layoutProvider(for: metadata.blockType)
                exclusionPaths.append(contentsOf: provider.exclusionPaths(for: paragraphRange, in: self, metadata: metadata))
            }
        }
        textContainer.exclusionPaths = exclusionPaths
        // Prefer throttled refresh instead of immediate full layout invalidation
        scheduleThrottledLayoutUpdate()
    }
    
    // MARK: - Image View Management
    
    /// Update image views for image-text blocks
    internal func updateImageViews() {
        // Remove image views that no longer exist
        var currentImageRefs = Set<UUID>()
        let string = textStorage.string as NSString
        guard string.length > 0 else {
            for (_, imageView) in imageViews {
                imageView.removeFromSuperview()
            }
            imageViews.removeAll()
            return
        }
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard let metadata = metadata,
                  metadata.blockType == .imageText,
                  let imageRef = metadata.imageReference,
                  paragraphRange.location < string.length,
                  NSMaxRange(paragraphRange) <= string.length else { return }
            let paragraphText = string.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraphText.isEmpty else { return }
            currentImageRefs.insert(imageRef)
        }
        for (imageRef, imageView) in imageViews {
            if !currentImageRefs.contains(imageRef) {
                imageView.removeFromSuperview()
                imageViews.removeValue(forKey: imageRef)
            }
        }
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard let metadata = metadata,
                  metadata.blockType == .imageText,
                  let imageRef = metadata.imageReference,
                  paragraphRange.location < string.length,
                  NSMaxRange(paragraphRange) <= string.length else { return }
            let paragraphText = string.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraphText.isEmpty else { return }
            let boundingRect = self.boundingRect(for: paragraphRange)
            let containerWidth = self.textContainer.size.width - self.textContainer.lineFragmentPadding * 2
            let imageWidth = containerWidth * 0.3
            var imageHeight: CGFloat = max(100, boundingRect.height)
            var imageFrame = CGRect(
                x: 0,
                y: boundingRect.origin.y, // Always anchor to top of block
                width: imageWidth,
                height: imageHeight
            )
            imageFrame.origin.x += self.textContainerInset.left + self.textContainer.lineFragmentPadding
            imageFrame.origin.y += self.textContainerInset.top
            imageFrame.size.width -= 8
            let imageView: UIView
            if let existingView = imageViews[imageRef] {
                imageView = existingView
            } else {
                if let image = self.imageMap[imageRef] {
                    // Use image aspect ratio for height if possible
                    let aspectRatio = image.size.height / max(image.size.width, 1)
                    imageHeight = min(max(imageWidth * aspectRatio, 100), 420) // Cap height
                    imageFrame.size.height = imageHeight
                    let imageViewObj = UIImageView(image: image)
                    imageViewObj.contentMode = .scaleAspectFill
                    imageViewObj.clipsToBounds = true
                    imageViewObj.layer.cornerRadius = 4.0
                    imageView = imageViewObj
                } else {
                    imageView = createImagePlaceholderView(imageWidth: imageWidth, imageHeight: imageHeight)
                }
                imageViews[imageRef] = imageView
                addSubview(imageView)
            }
            imageView.frame = imageFrame
        }
    }
    
    /// Create a placeholder image view
    internal func createImagePlaceholderView(imageWidth: CGFloat = 100, imageHeight: CGFloat = 120) -> UIView {
        // #if canImport(SwiftUI)
        // let imageComponent = ImageComponent(uiImage: nil, isLarge: false, onDelete: nil, onLongPress: nil)
        // let hostingController = UIHostingController(rootView: imageComponent.frame(width: imageWidth, height: imageHeight))
        // hostingController.view.backgroundColor = UIColor.clear
        // hostingController.view.frame = CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
        // return hostingController.view
        // #else
        let view = UIView()
        view.backgroundColor = UIColor.systemGray4
        view.layer.cornerRadius = 4.0
        view.frame = CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
        return view
        // #endif
    }
    
    // MARK: - Block Background Management
    
    /// Update block background views
    internal func updateBlockBackgroundViews() {
        // Remove block background views that no longer exist
        var currentBlockKeys = Set<String>()

        let string = textStorage.string as NSString
        guard string.length > 0 else {
            for (_, backgroundView) in blockBackgroundViews { backgroundView.removeFromSuperview() }
            blockBackgroundViews.removeAll()
            return
        }

        // We will iterate paragraphs in order and map to blocks by index
        var blockIndex = 0
        var paragraphInfos: [(NSRange, UnifiedTextContentStorage.BlockMetadata?, Int)] = []
        unifiedContentStorage.enumerateParagraphs { paragraphRange, metadata in
            guard paragraphRange.location < string.length else { return }
            let paragraphText = string.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraphText.isEmpty else { return }
            paragraphInfos.append((paragraphRange, metadata, blockIndex))
            blockIndex += 1
        }

        // Track existing keys from current paragraphs
        for (paragraphRange, _, _) in paragraphInfos {
            let key = "\(paragraphRange.location):\(paragraphRange.length)"
            currentBlockKeys.insert(key)
        }

        // Remove views for blocks that no longer exist
        for (blockKey, backgroundView) in blockBackgroundViews {
            if !currentBlockKeys.contains(blockKey) {
                backgroundView.removeFromSuperview()
                blockBackgroundViews.removeValue(forKey: blockKey)
            }
        }
        // Remove calorie labels for blocks that no longer exist
        for (blockKey, labelView) in calorieLabelViews {
            if !currentBlockKeys.contains(blockKey) {
                labelView.removeFromSuperview()
                calorieLabelViews.removeValue(forKey: blockKey)
            }
        }

        // Create/update views and calorie labels using current blocks snapshot
        for (paragraphRange, metadata, index) in paragraphInfos {
            let blockKey = "\(paragraphRange.location):\(paragraphRange.length)"
            let boundingRect = self.boundingRect(for: paragraphRange)
            var blockFrame = boundingRect
            blockFrame.origin.x += self.textContainerInset.left
            blockFrame.origin.y += self.textContainerInset.top
            let totalBlockWidth = self.bounds.width - self.textContainerInset.left - self.textContainerInset.right

            // Determine blockType and calories from model when possible
            let modelBlock: Block? = index < self.blocks.count ? self.blocks[index] : nil
            let blockTypeFromModel: UnifiedTextContentStorage.BlockMetadata.BlockType? = {
                guard let b = modelBlock else { return nil }
                switch b.type {
                case .text: return .text
                case .imageText: return .imageText
                case .image: return .imageText // treat as image region for layout
                case .spacer: return .spacer
                }
            }()
            let blockType = metadata?.blockType ?? blockTypeFromModel ?? .text
            let provider = layoutProvider(for: blockType)
            if blockType == .imageText {
                blockFrame.size.height = max(100, blockFrame.height)
                blockFrame.size.width = totalBlockWidth
                blockFrame.origin.x = self.textContainerInset.left
            } else {
                blockFrame.size.width = totalBlockWidth
            }
            blockFrame = blockFrame.insetBy(dx: 0, dy: 3)

            let backgroundView: UIView
            if let existingView = blockBackgroundViews[blockKey] {
                backgroundView = existingView
            } else {
                backgroundView = createBlockBackgroundView(for: blockType)
                blockBackgroundViews[blockKey] = backgroundView
                insertSubview(backgroundView, at: 0)
            }
            backgroundView.frame = blockFrame
            updateBlockBackgroundAppearance(backgroundView, for: blockType)

            // Compute calories text from metadata only (avoid leaking other blocks' values)
            let caloriesText: String = {
                if let m = metadata {
                    #if DEBUG
                    if let cd = m.calorieData {
                        print("🧪 Metadata at \(blockKey) calorieData='\(cd)'")
                    } else {
                        print("🧪 Metadata at \(blockKey) has no calorieData")
                    }
                    #endif
                    if let cd = m.calorieData, !cd.isEmpty {
                        return CalorieFormatter.format(cd)
                    }
                    if let data = m.nutritionJSON, let nutrition = try? JSONDecoder().decode(NutritionData.self, from: data) {
                        if let cal = nutrition.calories {
                            #if DEBUG
                            print("🧪 Metadata at \(blockKey) nutrition.calories=\(cal)")
                            #endif
                            return CalorieFormatter.format(cal)
                        } else {
                            // Derive from macros
                            if let p = nutrition.protein, let f = nutrition.fat, let c = nutrition.carbs {
                                let estimate = Int(((p * 4.0) + (f * 9.0) + (c * 4.0)).rounded())
                                #if DEBUG
                                print("🧪 Metadata at \(blockKey) derived from macros=\(estimate)")
                                #endif
                                return CalorieFormatter.format(estimate)
                            }
                        }
                    }
                }
                return CalorieFormatter.format(nil as String?)
            }()
            // Only show for text-bearing blocks
            switch blockType {
            case .text, .imageText:
                let calorieLabel: CalorieBlockView
                if let existing = calorieLabelViews[blockKey] {
                    calorieLabel = existing
                } else {
                    let newView = CalorieBlockView()
                    calorieLabelViews[blockKey] = newView
                    backgroundView.addSubview(newView)
                    calorieLabel = newView
                }
                calorieLabel.setCaloriesAnimated(caloriesText)
                #if DEBUG
                print("🏷️ Calorie label \(blockKey) text='\(caloriesText)'")
                #endif
                if let calorieLabelFrame = provider.calorieLabelFrame(for: paragraphRange, in: self, metadata: metadata ?? UnifiedTextContentStorage.BlockMetadata(blockType: blockType, blockSpacing: defaultBlockSpacing, imageReference: nil, calorieData: nil, nutritionJSON: nil), blockFrame: blockFrame) {
                    calorieLabel.frame = calorieLabelFrame
                } else {
                    // fallback: right-align inside block
                    let labelW: CGFloat = 80
                    calorieLabel.frame = CGRect(x: blockFrame.width - labelW - 8, y: 0, width: labelW, height: 20)
                }
            case .spacer:
                break
            }
        }
    }
    
    /// Create a block background view
    private func createBlockBackgroundView(for blockType: UnifiedTextContentStorage.BlockMetadata.BlockType) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false // Don't interfere with text editing
        updateBlockBackgroundAppearance(view, for: blockType)
        return view
    }
    
    /// Update block background view appearance
    private func updateBlockBackgroundAppearance(_ view: UIView, for blockType: UnifiedTextContentStorage.BlockMetadata.BlockType) {
        // Make backgrounds transparent (hide debug tint), but keep container for label layout
        view.backgroundColor = UIColor.clear
    }
}

// CalorieLabelView replaced by CalorieBlockView

// --- Helper to get last line rect for a paragraph ---
extension UnifiedTextView {
    /// Returns the rect (in view coordinates) for the last line of a paragraph range
    func lastLineRect(for paragraphRange: NSRange) -> CGRect? {
        guard paragraphRange.length > 0 else { return nil }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: paragraphRange, actualCharacterRange: nil)
        guard glyphRange.length > 0 else { return nil }
        let lastGlyphIndex = glyphRange.location + glyphRange.length - 1
        var lineRange = NSRange(location: 0, length: 0)
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: lastGlyphIndex, effectiveRange: &lineRange)
        // Convert from text container to view coordinates
        var rect = lineRect
        rect.origin.x += textContainerInset.left
        rect.origin.y += textContainerInset.top
        return rect
    }
}

// Helper to get the correct layout provider
private func layoutProvider(for blockType: UnifiedTextContentStorage.BlockMetadata.BlockType) -> BlockLayoutProviding {
    switch blockType {
    case .text:
        return TextBlockLayout()
    case .imageText:
        return ImageTextBlockLayout()
    case .spacer:
        return TextBlockLayout() // Or create a SpacerBlockLayout if needed
    }
} 
