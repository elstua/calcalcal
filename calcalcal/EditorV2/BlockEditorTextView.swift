import UIKit
import SwiftUI
import Combine

struct BlockEditorConfiguration {
    var initialText: String = ""
}

final class BlockEditorTextView: UITextView, UITextViewDelegate {
    /// Marker character used to represent an image block in the text storage.
    /// We use the object replacement character (U+FFFC) which is what
    /// NSTextAttachment normally uses, but we don't actually attach anything.
    static let imageMarker: String = "\u{FFFC}"

    /// Zero Width Space character used to mark placeholder text
    static let placeholderMarker: String = "\u{200B}"

    // MARK: - Spacing Constants (design system)

    /// Spacing for regular paragraph blocks
    private static let paragraphSpacing: CGFloat = DSSpacing.md
    private static let paragraphSpacingBefore: CGFloat = 10  // Slightly tighter than smd (12) for paragraph break

    /// Spacing for image blocks when text is shorter than image (push next content below the image)
    private static let imageSpacingLarge: CGFloat = 88
    /// Spacing for image blocks when text is taller than image (text already pushed content down)
    private static let imageSpacingSmall: CGFloat = DSSpacing.md
    private static let imageSpacingBefore: CGFloat = DSSpacing.sm

    /// Max number of text lines that still use the larger spacing.
    private static let imageLineThreshold: Int = 2

    // Lazily constructed after TextKit 2 stack is available.
    lazy var blockDocumentController: BlockDocumentController = {
        guard
            let textLayoutManager = self.textLayoutManager,
            let contentManager = textLayoutManager.textContentManager,
            let textContentStorage = contentManager as? NSTextContentStorage,
            let textStorage = textContentStorage.textStorage
        else {
            fatalError("Expected TextKit 2 stack with NSTextContentStorage and NSTextStorage")
        }
        return BlockDocumentController(textStorage: textStorage, contentManager: contentManager)
    }()

    lazy var blockLayoutController: BlockTextLayoutController = {
        let controller = BlockTextLayoutController(documentController: blockDocumentController)
        if let textLayoutManager = self.textLayoutManager {
            controller.attach(to: textLayoutManager)
        }
        return controller
    }()

    /// Maps BlockID to the overlay hosting controller for image blocks.
    private var imageOverlays: [BlockID: UIHostingController<ImageComponent>] = [:]
    /// Maps BlockID to calorie overlay views.
    private var calorieOverlays: [BlockID: CalorieBlockView] = [:]
    /// Cached exclusion paths contributed by image overlays.
    private var cachedImageExclusionPaths: [UIBezierPath] = []
    /// Tracks whether a deferred calorie overlay update is already scheduled.
    private var isCalorieOverlayUpdateScheduled = false

    /// Images associated with block IDs (set when inserting image blocks).
    private var imagesByBlockID: [BlockID: UIImage] = [:]

    /// Cached spacing decisions for image blocks: BlockID -> (lineCount, spacing).
    /// Only recalculate when the number of visual lines changes.
    private var imageSpacingCache: [BlockID: (lineCount: Int, spacing: CGFloat)] = [:]

    /// Entry identifier used to scope metadata notifications and backend synchronization.
    var entryIdentifier: UUID?

    /// Called when a new image overlay is positioned for the first time, providing
    /// the overlay's window-space frame. Used by EditorOverlay to animate a snapshot
    /// from the picker to the editor destination.
    var onNewImageOverlayPositioned: ((BlockID, CGRect) -> Void)?

    /// Called when the user commits a paragraph by pressing return.
    var onParagraphCommitted: (() -> Void)?

    /// Called when editing ends after changing a saved paragraph.
    var onSavedParagraphEdited: (() -> Void)?

    /// Called after the text view's content changes so SwiftUI can snapshot the
    /// current block document without going through NotificationCenter.
    var onTextChanged: (() -> Void)?

    /// Called after manual metadata edits are applied.
    var onMetadataApplied: (() -> Void)?

    /// When true, newly created image overlays start hidden (alpha 0).
    /// The fly-to animation coordinator will unhide them on completion.
    var pendingFlyToAnimation: Bool = false
    
    /// External scroll delegate to forward scroll events (used by BlockEditorRepresentable coordinator)
    weak var scrollDelegate: UIScrollViewDelegate?

    /// Flag to prevent re-entry during style application.
    private var isApplyingStyles = false
    /// Tracks pending block-style applications to avoid running while TextKit is mid-edit.
    private var isBlockStyleUpdateScheduled = false
    private var metadataSubscription: AnyCancellable?

    init(configuration: BlockEditorConfiguration = BlockEditorConfiguration()) {
        super.init(frame: .zero, textContainer: nil)

        // Force lazy properties to initialize so our controllers are ready.
        _ = blockDocumentController
        _ = blockLayoutController

        // Observe layout changes to reposition image overlays.
        blockDocumentController.onDocumentChange = { [weak self] in
            guard let self else { return }

            // Clean up spacing cache for deleted blocks
            self.cleanupSpacingCache()

            // Re-apply paragraph styles after the document is rebuilt so every block
            // picks up the correct spacing for its kind. Defer onto the next run loop
            // so we don't touch text storage while TextKit is still mutating it.
            self.scheduleBlockStyleApplication()

            // Defer image overlay updates to the next run loop so TextKit has
            // finished processing the edit. Calling during didProcessEditing can
            // hit stale NSTextParagraph data and crash (index out of range).
            DispatchQueue.main.async { [weak self] in
                self?.updateImageOverlays()
            }
            self.scheduleCalorieOverlayUpdate()
        }

        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false

        backgroundColor = .clear
        alwaysBounceVertical = true
        contentInsetAdjustmentBehavior = .automatic
        // Padding inside the scrollable text area (design system: top xxl, sides lg, bottom md)
        // Note: When used in EditorOverlay, this will be adjusted via setTopInset() to account for the sticky header
        textContainerInset = UIEdgeInsets(
            top: DSSpacing.xxl,
            left: DSSpacing.lg,
            bottom: DSSpacing.md,
            right: DSSpacing.lg
        )
        textDragInteraction?.isEnabled = true
        isScrollEnabled = true
        allowsEditingTextAttributes = false
        smartInsertDeleteType = .yes
        spellCheckingType = .yes
        autocorrectionType = .yes

        // Build a paragraph style with spacing that will be inherited by every
        // new paragraph as the user types. This keeps the storage and layout in
        // sync so caret/selection geometry matches what's drawn on screen.
        let baseFont = UIFont.dsBody
        let baseColor = UIColor.dsTextPrimary
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = Self.paragraphSpacingBefore
        paragraphStyle.paragraphSpacing = Self.paragraphSpacing
        paragraphStyle.lineHeightMultiple = 1.20

        let attrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: baseColor,
            .paragraphStyle: paragraphStyle
        ]
        attributedText = NSAttributedString(string: configuration.initialText, attributes: attrs)
        typingAttributes = attrs
        blockDocumentController.forceRebuild()

        // Set self as delegate to intercept text changes (Enter key handling).
        delegate = self

        // Force layout invalidation so our custom layout fragments are created.
        textLayoutManager?.textViewportLayoutController.layoutViewport()

    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTextIfNeeded(_ text: String) {
        guard self.text != text else { return }
        let baseFont = UIFont.dsBody
        let baseColor = UIColor.dsTextPrimary
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = Self.paragraphSpacingBefore
        paragraphStyle.paragraphSpacing = Self.paragraphSpacing
        paragraphStyle.lineHeightMultiple = 1.14

        let attrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: baseColor,
            .paragraphStyle: paragraphStyle
        ]
        attributedText = NSAttributedString(string: text, attributes: attrs)
        typingAttributes = attrs
        blockDocumentController.forceRebuild()
    }

    func subscribeToMetadataUpdates(_ publisher: PassthroughSubject<EditorMetadataUpdate, Never>) {
        metadataSubscription = publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.applyMetadataUpdate(update)
            }
    }

    func applyMetadataUpdate(_ update: EditorMetadataUpdate) {
        guard let entryIdentifier,
              UUID(uuidString: update.entryId) == entryIdentifier else {
            return
        }

        let analyzedBlocks = parseAnalyzedBlocks(from: update.analyzedBlocks as Any?)
        guard !analyzedBlocks.isEmpty else { return }
        applyAnalyzedMetadata(analyzedBlocks)

        // Explicitly trigger overlay update after applying metadata
        // This ensures CalorieBlockView overlays are created/updated immediately
        scheduleCalorieOverlayUpdate()
    }

    /// Moves the insertion point to the end of the rendered diary content and
    /// scrolls the bottom of the editor into view.
    func moveCaretToEndOfDocument() {
        let storageLength = (textLayoutManager?.textContentManager as? NSTextContentStorage)?
            .textStorage?
            .length ?? attributedText.length

        selectedRange = NSRange(location: storageLength, length: 0)
        typingAttributes = standardParagraphAttributes

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.layoutIfNeeded()
            if storageLength > 0 {
                self.scrollRangeToVisible(NSRange(location: max(storageLength - 1, 0), length: 1))
            }

            let bottomOffsetY = self.contentSize.height - self.bounds.height + self.adjustedContentInset.bottom
            let minimumOffsetY = -self.adjustedContentInset.top
            let targetOffsetY = max(minimumOffsetY, bottomOffsetY)
            self.setContentOffset(CGPoint(x: self.contentOffset.x, y: targetOffsetY), animated: false)
        }
    }
    
    /// Sets a custom top inset for the text content (used by EditorOverlay to leave space for header)
    func setTopInset(_ topInset: CGFloat) {
        guard textContainerInset.top != topInset else { return }
        textContainerInset = UIEdgeInsets(
            top: topInset,
            left: textContainerInset.left,
            bottom: textContainerInset.bottom,
            right: textContainerInset.right
        )
    }

    /// Sets a custom bottom inset for the text content (used by EditorOverlay to leave space for footer)
    func setBottomInset(_ bottomInset: CGFloat) {
        guard textContainerInset.bottom != bottomInset else { return }
        textContainerInset = UIEdgeInsets(
            top: textContainerInset.top,
            left: textContainerInset.left,
            bottom: bottomInset,
            right: textContainerInset.right
        )
    }

    /// Helper to insert an image block at the current cursor position.
    /// Instead of using an attachment (which would affect caret size), we insert
    /// a marker character and overlay `ImageComponent` as a subview.
    /// Text flows around the image using exclusion paths (no headIndent needed).
    func insertImageBlock(image: UIImage) {
        // Generate a new block ID for this image.
        let blockID = BlockID()
        imagesByBlockID[blockID] = image

        let baseFont = UIFont.dsBody
        let baseColor = UIColor.dsTextPrimary

        // Paragraph style for image block - NO headIndent!
        // Text will flow around the image via exclusion paths.
        // Start with large spacing (new image blocks have short text).
        let imageParagraphStyle = NSMutableParagraphStyle()
        imageParagraphStyle.paragraphSpacingBefore = Self.imageSpacingBefore
        imageParagraphStyle.paragraphSpacing = Self.imageSpacingLarge
        imageParagraphStyle.lineHeightMultiple = 1.14

        // Attributes for the marker character (invisible, tags the block).
        let markerAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: UIColor.clear,
            .paragraphStyle: imageParagraphStyle,
            BlockAttributeKeys.imageBlockID: blockID.rawValue
        ]

        // Attributes for text in the image block (same style, no indent).
        let imageTextAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: baseColor,
            .paragraphStyle: imageParagraphStyle
        ]

        // Normal paragraph style for text after the image block
        let normalParagraphStyle = NSMutableParagraphStyle()
        normalParagraphStyle.paragraphSpacingBefore = Self.paragraphSpacingBefore
        normalParagraphStyle.paragraphSpacing = Self.paragraphSpacing
        normalParagraphStyle.lineHeightMultiple = 1.14

        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: baseColor,
            .paragraphStyle: normalParagraphStyle
        ]

        // Build: marker + sample text + newline (newline uses NORMAL style so next paragraph has normal spacing)
        let markerPart = NSAttributedString(string: Self.imageMarker, attributes: markerAttrs)
        let sampleText = NSAttributedString(string: "Description here", attributes: imageTextAttrs)
        let newlinePart = NSAttributedString(string: "\n", attributes: normalAttrs)

        let mutable = NSMutableAttributedString(attributedString: attributedText ?? NSAttributedString())
        let insertionIndex = max(0, min(selectedRange.location, mutable.length))

        mutable.insert(markerPart, at: insertionIndex)
        mutable.insert(sampleText, at: insertionIndex + 1)
        mutable.insert(newlinePart, at: insertionIndex + 1 + sampleText.length)

        attributedText = mutable
        blockDocumentController.forceRebuild()

        // Place cursor at the end of the sample text so user can edit it.
        let cursorPosition = insertionIndex + 1 + sampleText.length
        selectedRange = NSRange(location: min(cursorPosition, mutable.length), length: 0)

        // Set typing attributes - same style, no indent
        typingAttributes = imageTextAttrs

        // Trigger overlay and exclusion path update.
        updateImageOverlays()
    }

    func setCalorieLabel(_ label: String?, for blockID: BlockID) {
        blockDocumentController.setCalorieLabel(label, for: blockID)
    }

    func setCalorieLabels(_ labels: [BlockID: String]) {
        blockDocumentController.setCalorieLabels(labels)
    }

    func setNutritionData(_ nutrition: [BlockID: NutritionData]) {
        blockDocumentController.setNutritionData(nutrition)
    }

    /// Replaces the current image overlay map and schedules a fresh layout pass.
    func setImageMap(_ images: [BlockID: UIImage]) {
        imagesByBlockID = images
        updateImageOverlays()
    }

    /// Returns the current overlay image for a given block, if any.
    func image(for blockID: BlockID) -> UIImage? {
        imagesByBlockID[blockID]
    }

    /// Reveals a previously hidden image overlay (used after fly-to animation completes).
    func revealImageOverlay(for blockID: BlockID) {
        guard let host = imageOverlays[blockID] else { return }
        UIView.animate(withDuration: 0.15) {
            host.view.alpha = 1
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        updateImageOverlays()
        scheduleCalorieOverlayUpdate()
    }

    /// Size of the image component in "small" mode
    private let imageComponentSize = ImageComponent.editorCardSize

    /// Positions `ImageComponent` overlays and sets up exclusion paths so text flows around images.
    private func updateImageOverlays() {
        // Get current text storage length for bounds validation
        guard let textStorage = (textLayoutManager?.textContentManager as? NSTextContentStorage)?.textStorage else {
            return
        }
        let storageLength = textStorage.length
        
        // Collect current image blocks from the document, filtering out stale blocks.
        // During deletion, block metadata can temporarily point to invalid ranges.
        let imageBlocks = blockDocumentController.document.blocks.filter { block in
            block.kind.isImage && block.range.location < storageLength && NSMaxRange(block.range) <= storageLength
        }

        // Remove overlays for blocks that no longer exist.
        let currentIDs = Set(imageBlocks.map { $0.id })
        for (id, host) in imageOverlays where !currentIDs.contains(id) {
            host.view.removeFromSuperview()
            imageOverlays.removeValue(forKey: id)
        }

        // Build exclusion paths for all image blocks
        var imageExclusionPaths: [UIBezierPath] = []

        // Create or update overlays for each image block.
        for block in imageBlocks {
            guard let uiImage = imageForBlock(block) else { continue }
            guard let rect = rectForBlock(block) else { continue }

            let host: UIHostingController<ImageComponent>
            var isNewOverlay = false
            if let existing = imageOverlays[block.id] {
                host = existing
            } else {
                let view = ImageComponent(
                    asset: nil,
                    uiImage: uiImage,
                    isLarge: false,
                    onDelete: nil,
                    onLongPress: nil
                )
                host = UIHostingController(rootView: view)
                host.view.backgroundColor = .clear
                let shouldHideForAnimation = pendingFlyToAnimation
                if shouldHideForAnimation {
                    host.view.alpha = 0
                    // Consume the flag immediately so only this overlay is hidden
                    pendingFlyToAnimation = false
                }
                addSubview(host.view)
                imageOverlays[block.id] = host
                isNewOverlay = true
            }

            // Position the overlay at the left edge of the text container,
            // aligned vertically with the marker's line.
            let imageFrame = CGRect(
                x: textContainerInset.left,
                y: rect.minY + textContainerInset.top,
                width: imageComponentSize.width,
                height: imageComponentSize.height
            )
            host.view.frame = imageFrame

            // Report destination rect for fly-to animation
            if isNewOverlay, let callback = onNewImageOverlayPositioned {
                let windowFrame = host.view.convert(host.view.bounds, to: nil)
                callback(block.id, windowFrame)
            }

            // Create exclusion path for this image in text container coordinates.
            // The exclusion path is relative to the text container, not the view.
            let exclusionRect = CGRect(
                x: 0, // Start at left edge of text container
                y: rect.minY,
                width: imageComponentSize.width + DSSpacing.sm, // Image width + DS padding
                height: imageComponentSize.height
            )
            let exclusionPath = UIBezierPath(rect: exclusionRect)
            imageExclusionPaths.append(exclusionPath)
        }

        cachedImageExclusionPaths = imageExclusionPaths
        applyExclusionPaths(with: imageExclusionPaths)
    }

    /// Positions calorie overlays on the last visible line for each text block.
    private func updateCalorieOverlays() {
        isCalorieOverlayUpdateScheduled = false

        guard
            let textStorage = (textLayoutManager?.textContentManager as? NSTextContentStorage)?.textStorage,
            textStorage.length > 0
        else {
            return
        }

        let labeledBlocks = blockDocumentController.document.blocks.filter { block in
            guard let text = block.calorieLabel else { return false }
            return !text.isEmpty
        }

        let activeIDs = Set(labeledBlocks.map { $0.id })
        for (id, view) in calorieOverlays where !activeIDs.contains(id) {
            view.removeFromSuperview()
            calorieOverlays.removeValue(forKey: id)
        }

        for block in labeledBlocks {
            guard block.range.location < textStorage.length else { continue }
            guard let labelText = block.calorieLabel,
                  let lineRect = lastLineRect(for: block) else {
                continue
            }

            let overlay: CalorieBlockView
            if let existing = calorieOverlays[block.id] {
                overlay = existing
            } else {
                let view = CalorieBlockView()
                addSubview(view)
                calorieOverlays[block.id] = view
                overlay = view
            }

            // Configure context menu
            let nutritionData = self.nutritionData(for: block.id)
            overlay.configureContextMenu(
                calories: nutritionData?.calories ?? 0,
                weight: nutritionData?.weight, // Use weight from nutrition data if available
                nutrition: nutritionData,
                blockID: block.id,
                presentingViewController: self.findViewController() ?? UIViewController(),
                onUpdate: { [weak self] updatedCalories, updatedWeight, blockID in
                    self?.handleCalorieUpdate(
                        calories: updatedCalories,
                        weight: updatedWeight,
                        blockID: blockID
                    )
                }
            )

            overlay.setCaloriesAnimated(labelText)

            let width = CalorieOverlayMetrics.labelMaxWidth
            let height = CalorieOverlayMetrics.labelHeight
            let x = bounds.width
                - textContainerInset.right
                - CalorieOverlayMetrics.horizontalEdgePadding
                - width
            let y = lineRect.midY - (height / 2.0)
            overlay.frame = CGRect(x: x, y: y, width: width, height: height)
        }

        applyExclusionPaths(with: cachedImageExclusionPaths)
    }

    private func applyExclusionPaths(with imagePaths: [UIBezierPath]) {
        var paths = imagePaths
        if shouldReserveCalorieColumn, let caloriePath = makeCalorieReservedPath() {
            paths.append(caloriePath)
        }
        textContainer.exclusionPaths = paths
    }

    private func makeCalorieReservedPath() -> UIBezierPath? {
        let reservedWidth = CalorieOverlayMetrics.reservedColumnWidth
        guard reservedWidth > 0 else { return nil }
        let containerWidth = textContainer.size.width
        guard containerWidth > 0 else { return nil }
        let width = min(reservedWidth, containerWidth)
        let x = max(0, containerWidth - width)
        let height = max(bounds.height, max(contentSize.height, 1))
        return UIBezierPath(rect: CGRect(x: x, y: 0, width: width, height: height))
    }

    private var shouldReserveCalorieColumn: Bool {
        blockDocumentController.document.blocks.contains {
            $0.calorieLabel?.isEmpty == false
        }
    }

    /// Returns the image associated with a block (looked up by custom attribute
    /// or by our local map).
    private func imageForBlock(_ block: BlockMetadata) -> UIImage? {
        // First check our local map.
        if let img = imagesByBlockID[block.id] {
            return img
        }
        // Fallback: check if BlockMetadata carries the image.
        return block.image
    }

    /// Returns the bounding rect for the first character of a block's range.
    private func rectForBlock(_ block: BlockMetadata) -> CGRect? {
        guard let textLayoutManager = textLayoutManager else { return nil }
        guard let contentManager = textLayoutManager.textContentManager else { return nil }

        // Validate block range against BOTH textStorage length and the content
        // manager's document range. During didProcessEditing callbacks these can
        // diverge, and passing a stale offset into NSTextContentStorage triggers
        // an NSInvalidArgumentException inside NSTextParagraph.
        guard let textStorage = (contentManager as? NSTextContentStorage)?.textStorage else {
            return nil
        }
        let storageLen = textStorage.length
        guard storageLen > 0,
              block.range.location >= 0,
              block.range.location + 1 <= storageLen else {
            return nil
        }

        // Also validate against the content manager's own document range offset
        let docRange = contentManager.documentRange
        let docEnd = contentManager.offset(from: docRange.location, to: docRange.endLocation)
        guard docEnd > 0, block.range.location + 1 <= docEnd else {
            return nil
        }

        guard let startLocation = contentManager.location(docRange.location, offsetBy: block.range.location) else {
            return nil
        }
        guard let endLocation = contentManager.location(startLocation, offsetBy: 1) else {
            return nil
        }
        guard let textRange = NSTextRange(location: startLocation, end: endLocation) else {
            return nil
        }

        // Ensure layout is valid for this range before enumerating segments.
        // If layout hasn't been performed yet for this range, enumerating can
        // hit stale paragraph data and crash.
        guard textLayoutManager.textLayoutFragment(for: startLocation) != nil else {
            return nil
        }

        var rect: CGRect?
        textLayoutManager.enumerateTextSegments(in: textRange, type: .standard, options: []) { _, segmentRect, _, _ in
            rect = segmentRect
            return false
        }
        return rect
    }

    private func textRange(for block: BlockMetadata) -> UITextRange? {
        guard block.range.length > 0 else { return nil }
        guard
            let contentStorage = textLayoutManager?.textContentManager as? NSTextContentStorage,
            let storage = contentStorage.textStorage,
            block.range.location < storage.length
        else {
            return nil
        }

        let availableLength = storage.length - block.range.location
        guard availableLength > 0 else { return nil }
        let safeLength = min(block.range.length, availableLength)
        guard safeLength > 0 else { return nil }

        guard
            let start = position(from: beginningOfDocument, offset: block.range.location),
            let end = position(from: start, offset: safeLength)
        else {
            return nil
        }

        return textRange(from: start, to: end)
    }

    private func lastLineRect(for block: BlockMetadata) -> CGRect? {
        guard let range = textRange(for: block) else {
            return caretRectFallback(for: block)
        }

        let usableRects = selectionRects(for: range)
            .map(\.rect)
            .filter { isUsable(rect: $0) && $0.width > 0.5 && $0.height > 0.5 }

        if let rect = usableRects.last {
            return rect
        }

        return caretRectFallback(for: block)
    }

    private func caretRectFallback(for block: BlockMetadata) -> CGRect? {
        guard
            let contentStorage = textLayoutManager?.textContentManager as? NSTextContentStorage,
            let storage = contentStorage.textStorage,
            storage.length > 0,
            block.range.location < storage.length
        else {
            return nil
        }

        let availableLength = storage.length - block.range.location
        let safeOffset = max(min(block.range.length, availableLength) - 1, 0)

        guard
            let start = position(from: beginningOfDocument, offset: block.range.location),
            let target = position(from: start, offset: safeOffset)
        else {
            return nil
        }

        let caret = caretRect(for: target)
        return isUsable(rect: caret) ? caret : nil
    }

    private func isUsable(rect: CGRect) -> Bool {
        guard !rect.isNull else { return false }
        guard rect.origin.x.isFinite, rect.origin.y.isFinite,
              rect.width.isFinite, rect.height.isFinite else {
            return false
        }
        return rect.width > 0 && rect.height > 0
    }

    /// Schedules calorie overlay updates on the next run loop tick to avoid racing
    /// with TextKit while it is mutating the text storage during editing.
    private func scheduleCalorieOverlayUpdate() {
        guard !isCalorieOverlayUpdateScheduled else { return }
        isCalorieOverlayUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.updateCalorieOverlays()
        }
    }

    /// Defers block style application so it runs after the current TextKit edit cycle finishes.
    private func scheduleBlockStyleApplication() {
        guard !isBlockStyleUpdateScheduled else { return }
        isBlockStyleUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isBlockStyleUpdateScheduled = false
            self.applyBlockStyles()
        }
    }

    // MARK: - Text Input Handling (UITextViewDelegate)

    /// Intercept text changes to fix paragraph style inheritance.
    /// When Enter is pressed, reset typingAttributes to standard BEFORE the newline is inserted.
    /// Also handles placeholder auto-deletion when user starts typing.
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Check if we're typing in a placeholder paragraph
        if !text.isEmpty && text != "\n" {
            if let placeholderRange = findPlaceholderRangeContaining(range.location) {
                // Remove the entire placeholder and insert the new text
                let mutable = NSMutableAttributedString(attributedString: attributedText)
                mutable.replaceCharacters(in: placeholderRange, with: text)
                attributedText = mutable
                selectedRange = NSRange(location: placeholderRange.location + text.count, length: 0)
                textViewDidChange(textView)
                return false
            }
        }

        if text == "\n" {
            // Always use standard paragraph attributes for new paragraphs.
            // Image blocks are created explicitly via insertImageBlock(), not by pressing Enter.
            typingAttributes = standardParagraphAttributes
            onParagraphCommitted?()
        }
        return true
    }

    /// Finds the range of a placeholder paragraph containing the given location
    private func findPlaceholderRangeContaining(_ location: Int) -> NSRange? {
        guard let textStorage = (textLayoutManager?.textContentManager as? NSTextContentStorage)?.textStorage,
              location <= textStorage.length else {
            return nil
        }

        // Find the paragraph containing this location
        let string = textStorage.string as NSString
        let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))

        // Check if this paragraph starts with the placeholder marker
        guard paragraphRange.location < textStorage.length else { return nil }

        let paragraphText = string.substring(with: paragraphRange)
        if paragraphText.hasPrefix(Self.placeholderMarker) {
            return paragraphRange
        }

        return nil
    }

    /// Standard paragraph attributes (no indent needed since we use exclusion paths).
    private var standardParagraphAttributes: [NSAttributedString.Key: Any] {
        let baseFont = UIFont.dsBody
        let baseColor = UIColor.dsTextPrimary
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = Self.paragraphSpacingBefore
        paragraphStyle.paragraphSpacing = Self.paragraphSpacing
        paragraphStyle.lineHeightMultiple = 1.14

        return [
            .font: baseFont,
            .foregroundColor: baseColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    /// Called after text changes - update exclusion paths (styles are handled by document change callback).
    func textViewDidChange(_ textView: UITextView) {
        updateImageOverlays()
        scheduleCalorieOverlayUpdate()
        onTextChanged?()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        onSavedParagraphEdited?()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Forward scroll events to external delegate (for header blur)
        scrollDelegate?.scrollViewDidScroll?(scrollView)
    }

    /// Called when cursor moves - set typing attributes based on current block type.
    func textViewDidChangeSelection(_ textView: UITextView) {
        let cursorLocation = selectedRange.location
        let currentBlock = blockDocumentController.block(containing: NSRange(location: cursorLocation, length: 0))

        // If NOT in an image block, reset typing attributes to normal
        if currentBlock == nil || !currentBlock!.kind.isImage {
            typingAttributes = standardParagraphAttributes
        }
    }

    /// Apply the correct paragraph style to EACH block independently.
    /// This normalizes paragraph styles after text changes (e.g., when pressing Enter
    /// splits a paragraph, the new paragraph inherits the old style and needs fixing).
    private func applyBlockStyles() {
        // Prevent re-entry
        guard !isApplyingStyles else { return }

        guard let textStorage = textLayoutManager?.textContentManager as? NSTextContentStorage,
              let storage = textStorage.textStorage,
              storage.length > 0 else { return }

        let blocks = blockDocumentController.document.blocks
        guard !blocks.isEmpty else { return }

        isApplyingStyles = true
        defer { isApplyingStyles = false }

        storage.beginEditing()

        for block in blocks {
            let range = block.range
            guard range.location < storage.length else { continue }

            // Clamp range to valid bounds
            let safeLength = min(range.length, storage.length - range.location)
            guard safeLength > 0 else { continue }
            let safeRange = NSRange(location: range.location, length: safeLength)

            // Determine target spacing based on block type
            let targetSpacing: CGFloat
            let targetSpacingBefore: CGFloat

            if block.kind.isImage {
                // For image blocks, use cached spacing or calculate if content changed.
                // Skip spacing calculation if block range extends beyond storage length
                // to avoid crashes from stale metadata during rapid edits.
                if NSMaxRange(block.range) <= storage.length {
                    targetSpacing = cachedSpacing(for: block)
                } else {
                    targetSpacing = Self.imageSpacingLarge // Safe fallback
                }
                targetSpacingBefore = Self.imageSpacingBefore
            } else {
                targetSpacing = Self.paragraphSpacing
                targetSpacingBefore = Self.paragraphSpacingBefore
            }

            // Check if this range already has the correct spacing
            if let existingStyle = storage.attribute(.paragraphStyle, at: safeRange.location, effectiveRange: nil) as? NSParagraphStyle {
                // Only update if spacing is wrong (tolerance of 1 to avoid floating point issues)
                if abs(existingStyle.paragraphSpacing - targetSpacing) > 1 ||
                   abs(existingStyle.paragraphSpacingBefore - targetSpacingBefore) > 1 {
                    let newStyle = existingStyle.mutableCopy() as! NSMutableParagraphStyle
                    newStyle.paragraphSpacing = targetSpacing
                    newStyle.paragraphSpacingBefore = targetSpacingBefore
                    storage.addAttribute(.paragraphStyle, value: newStyle, range: safeRange)
                }
            }

            let existingBlockID = storage.attribute(BlockAttributeKeys.blockIdentifier,
                                                    at: safeRange.location,
                                                    effectiveRange: nil)
            let existingUUID: UUID?
            if let uuid = existingBlockID as? UUID {
                existingUUID = uuid
            } else if let blockID = existingBlockID as? BlockID {
                existingUUID = blockID.rawValue
            } else {
                existingUUID = nil
            }

            if existingUUID != block.id.rawValue {
                storage.addAttribute(BlockAttributeKeys.blockIdentifier, value: block.id.rawValue, range: safeRange)
            }
        }

        storage.endEditing()

        // Also update typing attributes for current position
        updateTypingAttributesForCurrentBlock()
    }

    /// Returns cached spacing for an image block.
    /// Spacing only changes when the rendered text crosses the line threshold.
    private func cachedSpacing(for block: BlockMetadata) -> CGFloat {
        let currentLineCount = lineCount(for: block)

        if let cached = imageSpacingCache[block.id], cached.lineCount == currentLineCount {
            return cached.spacing
        }

        let spacing = currentLineCount <= Self.imageLineThreshold ? Self.imageSpacingLarge : Self.imageSpacingSmall
        imageSpacingCache[block.id] = (lineCount: currentLineCount, spacing: spacing)
        return spacing
    }

    /// Removes stale entries from the spacing cache (blocks that no longer exist).
    private func cleanupSpacingCache() {
        let currentImageBlockIDs = Set(blockDocumentController.document.blocks.filter { $0.kind.isImage }.map { $0.id })
        imageSpacingCache = imageSpacingCache.filter { currentImageBlockIDs.contains($0.key) }
    }

    /// Returns the rendered line count for a block's text content.
    /// Uses TextKit 2 layout fragments to count actual line fragments.
    private func lineCount(for block: BlockMetadata) -> Int {
        guard let textLayoutManager = textLayoutManager,
              let contentManager = textLayoutManager.textContentManager,
              let textStorage = (contentManager as? NSTextContentStorage)?.textStorage else {
            return 1
        }

        // Ensure layout reflects the latest edits.
        textLayoutManager.textViewportLayoutController.layoutViewport()

        guard block.range.location < textStorage.length else { return 1 }
        let availableLength = textStorage.length - block.range.location
        guard availableLength > 0 else { return 1 }
        let safeLength = max(1, min(block.range.length, availableLength))
        
        // Additional validation: ensure the computed end position won't exceed document bounds.
        // This prevents crashes from stale block metadata during rapid edits.
        let computedEnd = block.range.location + safeLength
        guard computedEnd <= textStorage.length else { return 1 }

        let docRange = contentManager.documentRange
        guard let startLocation = contentManager.location(docRange.location, offsetBy: block.range.location) else {
            return 1
        }
        guard let endLocation = contentManager.location(startLocation, offsetBy: safeLength) else {
            return 1
        }
        guard let textRange = NSTextRange(location: startLocation, end: endLocation) else {
            return 1
        }

        var totalLines = 0
        textLayoutManager.enumerateTextLayoutFragments(from: textRange.location,
                                                       options: [.ensuresLayout, .ensuresExtraLineFragment]) { fragment in
            let fragmentRange = fragment.rangeInElement
            let fragmentEnd = fragmentRange.endLocation

            guard fragmentEnd.compare(textRange.endLocation) != .orderedDescending else {
                return false
            }

            totalLines += fragment.textLineFragments.count
            return true
        }

        return max(totalLines, 1)
    }

    /// Set typing attributes based on current block type.
    private func updateTypingAttributesForCurrentBlock() {
        let cursorLocation = selectedRange.location
        let currentBlock = blockDocumentController.block(containing: NSRange(location: cursorLocation, length: 0))

        if let block = currentBlock, block.kind.isImage {
            // In image block - use cached spacing
            let spacing = cachedSpacing(for: block)

            let baseFont = UIFont.dsBody
            let baseColor = UIColor.dsTextPrimary
            let style = NSMutableParagraphStyle()
            style.paragraphSpacingBefore = Self.imageSpacingBefore
            style.paragraphSpacing = spacing
            style.lineHeightMultiple = 1.14

            typingAttributes = [
                .font: baseFont,
                .foregroundColor: baseColor,
                .paragraphStyle: style
            ]
        } else {
            // In paragraph block or new position - use standard spacing
            typingAttributes = standardParagraphAttributes
        }
    }

    // MARK: - Metadata Handling
    private struct AnalyzedBlock {
        let id: String
        let position: Int
        let content: String
        let calories: Int?
        let protein: Double?
        let fat: Double?
        let carbs: Double?
        let fiber: Double?
        let sugar: Double?
        let sodium: Double?
        let weight: Double?
        let confidence: Double?
        let aiAnalysis: String?
        let isAnalyzing: Bool
    }

    private func parseAnalyzedBlocks(from payload: Any?) -> [AnalyzedBlock] {
        if let blocks = payload as? [AnalyzedBlock] {
            return blocks
        }
        guard let dicts = payload as? [[String: Any]] else { return [] }
        return dicts.compactMap { dict in
            func parseInt(_ value: Any?) -> Int? {
                if let intValue = value as? Int { return intValue }
                if let number = value as? NSNumber { return number.intValue }
                if let string = value as? String { return Int(string) }
                return nil
            }
            func parseDouble(_ value: Any?) -> Double? {
                if let doubleValue = value as? Double { return doubleValue }
                if let number = value as? NSNumber { return number.doubleValue }
                if let string = value as? String { return Double(string) }
                return nil
            }
            func parseBool(_ value: Any?) -> Bool {
                if let boolValue = value as? Bool { return boolValue }
                if let number = value as? NSNumber { return number.boolValue }
                if let string = value as? String { return string == "true" || string == "1" }
                return false
            }
            let id = dict["id"] as? String ?? UUID().uuidString
            let position = parseInt(dict["position"]) ?? 0
            let content = (dict["content"] as? String) ?? ""
            let calories = parseInt(dict["calories"])
            return AnalyzedBlock(
                id: id,
                position: position,
                content: content,
                calories: calories,
                protein: parseDouble(dict["protein"]),
                fat: parseDouble(dict["fat"]),
                carbs: parseDouble(dict["carbs"]),
                fiber: parseDouble(dict["fiber"]),
                sugar: parseDouble(dict["sugar"]),
                sodium: parseDouble(dict["sodium"]),
                weight: parseDouble(dict["weight"]),
                confidence: parseDouble(dict["confidence"]),
                aiAnalysis: nil,
                isAnalyzing: parseBool(dict["isAnalyzing"])
            )
        }
    }

    private func applyAnalyzedMetadata(_ analyzedBlocks: [AnalyzedBlock]) {
        guard
            let textLayoutManager = textLayoutManager,
            let contentManager = textLayoutManager.textContentManager as? NSTextContentStorage,
            let textStorage = contentManager.textStorage
        else {
            return
        }

        let backingString = textStorage.string as NSString
        let metadataBlocks = blockDocumentController.document.blocks
        guard !metadataBlocks.isEmpty else { return }

        var paragraphs: [(index: Int, metadata: BlockMetadata, text: String)] = []
        for block in metadataBlocks {
            var text = textForBlock(block, in: backingString)
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty && !block.kind.isImage {
                continue
            }
            paragraphs.append((paragraphs.count, block, text))
        }

        guard !paragraphs.isEmpty else { return }

        var calorieMap = currentCalorieMap()
        var nutritionMap = currentNutritionMap()
        var matchedParagraphIndices = Set<Int>()
        var unmatchedAnalyzed: [AnalyzedBlock] = []

        let paragraphsByID = Dictionary(uniqueKeysWithValues: paragraphs.map { ($0.metadata.id.rawValue.uuidString, $0) })

        for analyzed in analyzedBlocks {
            if let paragraph = paragraphsByID[analyzed.id] {
                apply(analyzed, to: paragraph.metadata.id, calorieMap: &calorieMap, nutritionMap: &nutritionMap)
                if let idx = paragraphs.firstIndex(where: { $0.metadata.id == paragraph.metadata.id }) {
                    matchedParagraphIndices.insert(idx)
                }
                continue
            }

            let trimmedServer = analyzed.content.trimmingCharacters(in: .whitespacesAndNewlines)
            var matched = false
            for (idx, paragraph) in paragraphs.enumerated() where !matchedParagraphIndices.contains(idx) {
                let deviceText = paragraph.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !deviceText.isEmpty && !trimmedServer.isEmpty && deviceText == trimmedServer {
                    apply(analyzed, to: paragraph.metadata.id, calorieMap: &calorieMap, nutritionMap: &nutritionMap)
                    matchedParagraphIndices.insert(idx)
                    matched = true
                    break
                }
            }
            if !matched {
                unmatchedAnalyzed.append(analyzed)
            }
        }

        let remainingParagraphIndices = paragraphs.enumerated()
            .filter { !matchedParagraphIndices.contains($0.offset) }
            .map(\.offset)

        for (analyzed, paragraphIndex) in zip(unmatchedAnalyzed, remainingParagraphIndices) {
            let metadata = paragraphs[paragraphIndex].metadata
            apply(analyzed, to: metadata.id, calorieMap: &calorieMap, nutritionMap: &nutritionMap)
        }

        blockDocumentController.setCalorieLabels(calorieMap)
        blockDocumentController.setNutritionData(nutritionMap)
    }

    private func apply(_ analyzed: AnalyzedBlock,
                       to blockID: BlockID,
                       calorieMap: inout [BlockID: String],
                       nutritionMap: inout [BlockID: NutritionData]) {
        if analyzed.isAnalyzing {
            calorieMap[blockID] = CalorieBlockView.loadingToken
            return
        }

        if let calories = derivedCalories(from: analyzed) {
            calorieMap[blockID] = String(calories)
        } else if calorieMap[blockID] == CalorieBlockView.loadingToken {
            calorieMap.removeValue(forKey: blockID)
        }
        if let nutrition = nutritionData(from: analyzed) {
            nutritionMap[blockID] = nutrition
        }
    }

    private func textForBlock(_ metadata: BlockMetadata, in backingString: NSString) -> String {
        guard metadata.range.location < backingString.length else { return "" }
        var text = backingString.substring(with: metadata.range)
        if metadata.kind.isImage {
            text = text.replacingOccurrences(of: Self.imageMarker, with: "")
        }
        while let last = text.last, last.isNewline {
            text.removeLast()
        }
        return text
    }

    private func currentCalorieMap() -> [BlockID: String] {
        var map: [BlockID: String] = [:]
        for block in blockDocumentController.document.blocks {
            if let label = block.calorieLabel, !label.isEmpty {
                map[block.id] = label
            }
        }
        return map
    }

    private func currentNutritionMap() -> [BlockID: NutritionData] {
        var map: [BlockID: NutritionData] = [:]
        for block in blockDocumentController.document.blocks {
            if let nutrition = block.nutrition {
                map[block.id] = nutrition
            }
        }
        return map
    }

    private func derivedCalories(from analyzed: AnalyzedBlock) -> Int? {
        if let calories = analyzed.calories, calories > 0 {
            return calories
        }
        if let protein = analyzed.protein,
           let fat = analyzed.fat,
           let carbs = analyzed.carbs {
            let estimate = (protein * 4.0) + (fat * 9.0) + (carbs * 4.0)
            return Int(estimate.rounded())
        }
        return nil
    }

    private func nutritionData(from analyzed: AnalyzedBlock) -> NutritionData? {
        let hasMeaningfulData = (analyzed.calories ?? 0) > 0
            || (analyzed.protein ?? 0) > 0
            || (analyzed.fat ?? 0) > 0
            || (analyzed.carbs ?? 0) > 0
            || (analyzed.fiber ?? 0) > 0
            || (analyzed.sugar ?? 0) > 0
            || (analyzed.sodium ?? 0) > 0
            || (analyzed.weight ?? 0) > 0
        guard hasMeaningfulData else { return nil }
        return NutritionData(
            calories: analyzed.calories,
            protein: analyzed.protein,
            fat: analyzed.fat,
            carbs: analyzed.carbs,
            fiber: analyzed.fiber,
            sugar: analyzed.sugar,
            sodium: analyzed.sodium,
            weight: analyzed.weight,
            confidence: analyzed.confidence
        )
    }

    // MARK: - Helper Methods for Context Menu

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while responder != nil {
            if let viewController = responder as? UIViewController {
                return viewController
            }
            responder = responder?.next
        }
        return nil
    }

    private func handleCalorieUpdate(calories: Int?, weight: Double?, blockID: BlockID) {
        guard let entryIdentifier = entryIdentifier else {
            dlog("Error: No entry identifier available for calorie update")
            return
        }

        // Get the text content for this block
        guard let block = blockDocumentController.document.blocks.first(where: { $0.id == blockID }),
              let textStorage = (textLayoutManager?.textContentManager as? NSTextContentStorage)?.textStorage else {
            dlog("Error: Could not find block or text storage")
            return
        }

        let text = getBlockText(block: block, textStorage: textStorage)

        dlog("Updating calories for block \(blockID): calories=\(calories ?? -1), weight=\(weight ?? -1), text=\(text)")

        if let calories {
            applyVisibleCalorieUpdate(calories: calories, blockID: blockID)
        }

        // Make API call
        Task { [weak self] in
            do {
                let response = try await APIClient.shared.updateCaloriePopup(
                    entryId: entryIdentifier.uuidString,
                    blockId: blockID.rawValue.uuidString,
                    text: text,
                    calories: calories,
                    weight: weight
                )
                await MainActor.run {
                    self?.handleCalorieUpdateResponse(response: response, blockID: blockID)
                }
            } catch {
                dlog("Error updating calorie popup: \(error)")
                await MainActor.run {
                    if let apiError = error as? APIError {
                        self?.showErrorAlert(message: apiError.localizedDescription)
                    } else {
                        self?.showErrorAlert(message: "Failed to update nutrition information. Please try again.")
                    }
                }
            }
        }
    }

    private func handleCalorieUpdateResponse(response: CaloriePopupUpdateResponse, blockID: BlockID) {
        dlog("Successfully updated nutrition for block \(blockID): \(response)")

        // Update local nutrition data
        let updatedNutrition = NutritionData(
            calories: response.calories,
            protein: response.protein,
            fat: response.fat,
            carbs: response.carbs,
            fiber: response.fiber,
            sugar: response.sugar,
            sodium: response.sodium,
            weight: response.weight,
            metric_description: response.metric_description,
            confidence: response.confidence,
            userModified: true
        )

        // Reconcile macros and other nutrition fields from the backend without
        // dropping metadata for the other blocks in this entry.
        var nutritionMap = currentNutritionMap()
        nutritionMap[blockID] = updatedNutrition
        blockDocumentController.setNutritionData(nutritionMap)

        // Update the calorie overlay to show new calories
        if let calorieOverlay = calorieOverlays[blockID] {
            calorieOverlay.setCaloriesAnimated(String(response.calories))
        }

        // Update the calorie label in the document
        blockDocumentController.setCalorieLabel(String(response.calories), for: blockID)

        // Trigger a layout update
        scheduleCalorieOverlayUpdate()

        publishCalorieMetadataChange(nutritionMap: nutritionMap)
    }

    private func applyVisibleCalorieUpdate(calories: Int, blockID: BlockID) {
        var nutritionMap = currentNutritionMap()
        let existing = nutritionMap[blockID]
        let updatedNutrition = NutritionData(
            calories: calories,
            protein: existing?.protein,
            fat: existing?.fat,
            carbs: existing?.carbs,
            fiber: existing?.fiber,
            sugar: existing?.sugar,
            sodium: existing?.sodium,
            weight: existing?.weight,
            metric_description: existing?.metric_description,
            confidence: existing?.confidence,
            userModified: true
        )

        nutritionMap[blockID] = updatedNutrition
        blockDocumentController.setNutritionData(nutritionMap)
        blockDocumentController.setCalorieLabel(String(calories), for: blockID)

        if let calorieOverlay = calorieOverlays[blockID] {
            calorieOverlay.setCaloriesAnimated(String(calories))
        }

        scheduleCalorieOverlayUpdate()
        publishCalorieMetadataChange(nutritionMap: nutritionMap)
    }

    private func publishCalorieMetadataChange(nutritionMap: [BlockID: NutritionData]) {
        guard let entryId = self.entryIdentifier else { return }

        let totalCalories = nutritionMap.values.reduce(0) { total, nutrition in
            total + (nutrition.calories ?? 0)
        }

        DiaryEntryUpdatesCoordinator.shared.calorieUpdates.send(
            EntryCalorieUpdate(entryId: entryId, totalCalories: totalCalories)
        )

        onMetadataApplied?()
    }

    // MARK: - Helper Methods

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(
            title: "OK",
            style: .default,
            handler: nil
        ))

        // Find the view controller to present the alert
        if let viewController = self.findViewController() {
            viewController.present(alert, animated: true)
        }
    }

    private func getBlockText(block: BlockMetadata, textStorage: NSTextStorage) -> String {
        guard block.range.location < textStorage.length else { return "" }
        var text = textStorage.attributedSubstring(from: block.range).string

        // Remove image markers
        text = text.replacingOccurrences(of: Self.imageMarker, with: "")

        // Trim whitespace and newlines
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }

    private func nutritionData(for blockID: BlockID) -> NutritionData? {
        return blockDocumentController.document.blocks.first { $0.id == blockID }?.nutrition
    }
}
