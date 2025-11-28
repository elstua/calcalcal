import UIKit

/// Bridges the SwiftUI `Block` model with the TextKit 2-based `BlockEditorTextView`.
/// Responsible for rendering incoming blocks into the text view while preserving
/// caret state and metadata, and for rebuilding `[Block]` snapshots after user edits.
final class BlockEditorBridge {
    private weak var textView: BlockEditorTextView?
    private var cachedBlocksByID: [UUID: Block] = [:]
    private let newlineCharacterSet = CharacterSet.newlines
    private let whitespaceAndNewlineCharacterSet = CharacterSet.whitespacesAndNewlines

    private(set) var isApplyingExternalUpdate: Bool = false

    init(textView: BlockEditorTextView) {
        self.textView = textView
    }

    /// Applies the provided blocks to the underlying text view, replacing the rendered content.
    /// Existing metadata (calorie overlays, image overlays) is reapplied without forcing callers
    /// to mutate the text themselves.
    func apply(blocks: [Block], imageMap: [UUID: UIImage]) {
        guard let textView else { return }

        cachedBlocksByID = blocks.reduce(into: [:]) { dict, block in
            dict[block.id] = block
        }

        let font = currentFont(from: textView)
        let color = currentColor(from: textView)
        let attributedString = makeAttributedString(for: blocks, font: font, textColor: color)
        let previousSelection = textView.selectedRange

        isApplyingExternalUpdate = true
        defer { isApplyingExternalUpdate = false }

        textView.attributedText = attributedString
        textView.typingAttributes = standardAttributes(font: font, color: color)
        textView.blockDocumentController.forceRebuild()
        textView.setCalorieLabels(calorieLabels(from: blocks))
        textView.setImageMap(makeOverlayImages(from: blocks, imageMap: imageMap))
        textView.setNutritionData(nutritionMap(from: blocks))

        let clampedLocation = min(previousSelection.location, textView.textStorage.length)
        textView.selectedRange = NSRange(location: clampedLocation, length: 0)
    }

    /// Rebuilds a `[Block]` snapshot from the current text storage, preserving metadata from
    /// earlier renders whenever possible.
    func snapshotBlocks() -> [Block] {
        guard
            let textView = textView,
            let textLayoutManager = textView.textLayoutManager,
            let contentManager = textLayoutManager.textContentManager as? NSTextContentStorage,
            let textStorage = contentManager.textStorage
        else {
            return []
        }

        let backingString = textStorage.string as NSString
        var rebuilt: [Block] = []

        for metadata in textView.blockDocumentController.document.blocks {
            guard metadata.range.location < backingString.length else { continue }
            let substring = backingString.substring(with: metadata.range)
            let blockID = metadata.id.rawValue
            let previous = cachedBlocksByID[blockID]

            switch metadata.kind {
            case .paragraph:
                let paragraphText = trimTrailingNewlines(substring)
                let blockType: BlockType = {
                    if paragraphText.trimmingCharacters(in: whitespaceAndNewlineCharacterSet).isEmpty,
                       let previous,
                       case .spacer = previous.type {
                        return .spacer
                    }
                    return .text(paragraphText)
                }()

                var block = Block(type: blockType,
                                  calorieData: metadata.calorieLabel,
                                  nutrition: metadata.nutrition ?? previous?.nutrition)
                block.id = blockID
                block.imageUrl = previous?.imageUrl
                block.imageObjectKey = previous?.imageObjectKey
                block.stableId = previous?.stableId ?? previous?.id ?? block.id
                rebuilt.append(block)

            case .image:
                let stripped = removeImageMarker(from: substring)
                let cleaned = trimTrailingNewlines(stripped)
                let imageRef = resolveImageReference(in: textStorage, blockRange: metadata.range)
                    ?? previousImageReference(previous)
                    ?? UUID()
                let imageData = resolveImageData(for: imageRef, blockID: blockID, previousBlock: previous)

                var block = Block(type: .imageText(imageData, imageRef, cleaned),
                                  calorieData: metadata.calorieLabel,
                                  nutrition: metadata.nutrition ?? previous?.nutrition)
                block.id = blockID
                block.imageUrl = previous?.imageUrl
                block.imageObjectKey = previous?.imageObjectKey
                block.stableId = previous?.stableId ?? previous?.id ?? block.id
                rebuilt.append(block)
            }
        }

        cachedBlocksByID = Dictionary(uniqueKeysWithValues: rebuilt.map { ($0.id, $0) })
        return rebuilt
    }

    /// Updates only the overlay images using the last rendered block snapshot.
    func refreshImages(using imageMap: [UUID: UIImage]) {
        guard let textView else { return }
        let currentBlocks = Array(cachedBlocksByID.values)
        textView.setImageMap(makeOverlayImages(from: currentBlocks, imageMap: imageMap))
    }
}

// MARK: - Rendering helpers
private extension BlockEditorBridge {
    func makeAttributedString(for blocks: [Block], font: UIFont, textColor: UIColor) -> NSAttributedString {
        let attributed = NSMutableAttributedString()
        let standardAttrs = standardAttributes(font: font, color: textColor)

        for block in blocks {
            let startLocation = attributed.length

            switch block.type {
            case .text(let text):
                appendTextBlock(text, to: attributed, attributes: standardAttrs)

            case .image(let data, let ref):
                appendImageBlock(text: "", imageRef: ref, imageData: data, to: attributed, font: font, textColor: textColor)

            case .imageText(let data, let ref, let text):
                appendImageBlock(text: text, imageRef: ref, imageData: data, to: attributed, font: font, textColor: textColor)

            case .spacer:
                appendTextBlock("", to: attributed, attributes: standardAttrs)
            }

            let blockRange = NSRange(location: startLocation, length: attributed.length - startLocation)
            attributed.addAttribute(BlockAttributeKeys.blockIdentifier, value: block.id, range: blockRange)
        }

        return attributed
    }

    func appendTextBlock(_ text: String,
                         to attributed: NSMutableAttributedString,
                         attributes: [NSAttributedString.Key: Any]) {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        attributed.append(NSAttributedString(string: normalized, attributes: attributes))
        attributed.append(NSAttributedString(string: "\n", attributes: attributes))
    }

    func appendImageBlock(text: String,
                          imageRef: UUID,
                          imageData: Data,
                          to attributed: NSMutableAttributedString,
                          font: UIFont,
                          textColor: UIColor) {
        var markerAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.clear,
            BlockAttributeKeys.imageBlockID: imageRef
        ]

        // Preserve baseline alignment with surrounding text.
        if markerAttributes[.paragraphStyle] == nil {
            markerAttributes[.paragraphStyle] = standardParagraphStyle()
        }

        attributed.append(NSAttributedString(string: BlockEditorTextView.imageMarker,
                                             attributes: markerAttributes))

        var textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            BlockAttributeKeys.imageBlockID: imageRef
        ]
        if textAttributes[.paragraphStyle] == nil {
            textAttributes[.paragraphStyle] = standardParagraphStyle()
        }

        attributed.append(NSAttributedString(string: text.replacingOccurrences(of: "\r\n", with: "\n"),
                                             attributes: textAttributes))
        attributed.append(NSAttributedString(string: "\n", attributes: textAttributes))
    }

    func standardAttributes(font: UIFont, color: UIColor) -> [NSAttributedString.Key: Any] {
        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: standardParagraphStyle()
        ]
    }

    func standardParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = 10
        style.paragraphSpacing = 10
        style.lineHeightMultiple = 1.14
        return style
    }

    func currentFont(from textView: BlockEditorTextView) -> UIFont {
        if let font = textView.typingAttributes[.font] as? UIFont {
            return font
        }
        return UIFont.preferredFont(forTextStyle: .body)
    }

    func currentColor(from textView: BlockEditorTextView) -> UIColor {
        if let color = textView.typingAttributes[.foregroundColor] as? UIColor {
            return color
        }
        return UIColor.label
    }

    func calorieLabels(from blocks: [Block]) -> [BlockID: String] {
        var labels: [BlockID: String] = [:]
        for block in blocks {
            guard let text = block.calorieData, !text.isEmpty else { continue }
            labels[BlockID(rawValue: block.id)] = text
        }
        return labels
    }

    func makeOverlayImages(from blocks: [Block], imageMap: [UUID: UIImage]) -> [BlockID: UIImage] {
        var overlays: [BlockID: UIImage] = [:]
        for block in blocks {
            guard let payload = imagePayload(for: block) else { continue }
            let blockID = BlockID(rawValue: block.id)
            if let provided = imageMap[payload.ref] {
                overlays[blockID] = provided
            } else if let image = UIImage(data: payload.data) {
                overlays[blockID] = image
            }
        }
        return overlays
    }

    func nutritionMap(from blocks: [Block]) -> [BlockID: NutritionData] {
        var map: [BlockID: NutritionData] = [:]
        for block in blocks {
            guard let nutrition = block.nutrition else { continue }
            map[BlockID(rawValue: block.id)] = nutrition
        }
        return map
    }

    func imagePayload(for block: Block) -> (data: Data, ref: UUID)? {
        switch block.type {
        case .image(let data, let ref):
            return (data, ref)
        case .imageText(let data, let ref, _):
            return (data, ref)
        default:
            return nil
        }
    }
}

// MARK: - Snapshot helpers
private extension BlockEditorBridge {
    func trimTrailingNewlines(_ text: String) -> String {
        var copy = text
        while let last = copy.last, last.isNewline {
            copy.removeLast()
        }
        return copy
    }

    func removeImageMarker(from text: String) -> String {
        return text.replacingOccurrences(of: BlockEditorTextView.imageMarker, with: "")
    }

    func resolveImageReference(in textStorage: NSTextStorage, blockRange: NSRange) -> UUID? {
        if let uuid = textStorage.attribute(BlockAttributeKeys.imageBlockID,
                                            at: blockRange.location,
                                            effectiveRange: nil) as? UUID {
            return uuid
        }

        let upperBound = NSMaxRange(blockRange)
        var cursor = blockRange.location
        while cursor < upperBound {
            if let uuid = textStorage.attribute(BlockAttributeKeys.imageBlockID,
                                                at: cursor,
                                                effectiveRange: nil) as? UUID {
                return uuid
            }
            cursor += 1
        }
        return nil
    }

    func previousImageReference(_ block: Block?) -> UUID? {
        guard let block else { return nil }
        switch block.type {
        case .image(_, let ref):
            return ref
        case .imageText(_, let ref, _):
            return ref
        default:
            return nil
        }
    }

    func resolveImageData(for imageRef: UUID, blockID: UUID, previousBlock: Block?) -> Data {
        if let previousBlock {
            switch previousBlock.type {
            case .image(let data, let ref) where ref == imageRef:
                return data
            case .imageText(let data, let ref, _) where ref == imageRef:
                return data
            default:
                break
            }
        }
        if let textView,
           let image = textView.image(for: BlockID(rawValue: blockID)),
           let png = image.pngData() {
            return png
        }
        return Data()
    }
}

