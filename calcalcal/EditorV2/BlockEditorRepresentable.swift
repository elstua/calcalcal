import SwiftUI
import UIKit

struct BlockEditorRepresentable: UIViewRepresentable {
    @Binding var blocks: [Block]
    var imageMap: [UUID: UIImage]
    var isEditable: Bool
    @Binding var shouldBecomeFirstResponder: Bool
    @Binding var scrollOffset: CGFloat
    var entryId: UUID?
    var onBlocksChange: (([Block]) -> Void)?
    var onTextViewReady: ((BlockEditorTextView) -> Void)?
    var onNewImageOverlayPositioned: ((BlockID, CGRect) -> Void)?
    var pendingFlyToAnimation: Bool = false
    var topContentInset: CGFloat?  // Optional override for top inset (used by EditorOverlay for header space)
    var bottomContentInset: CGFloat?  // Optional override for bottom inset (used by EditorOverlay for footer space)
    
    init(blocks: Binding<[Block]>,
         imageMap: [UUID: UIImage] = [:],
         isEditable: Bool = true,
         shouldBecomeFirstResponder: Binding<Bool> = .constant(false),
         scrollOffset: Binding<CGFloat> = .constant(0),
         entryId: UUID? = nil,
         onBlocksChange: (([Block]) -> Void)? = nil,
         onTextViewReady: ((BlockEditorTextView) -> Void)? = nil,
         onNewImageOverlayPositioned: ((BlockID, CGRect) -> Void)? = nil,
         pendingFlyToAnimation: Bool = false,
         topContentInset: CGFloat? = nil,
         bottomContentInset: CGFloat? = nil) {
        self._blocks = blocks
        self.imageMap = imageMap
        self.isEditable = isEditable
        self._shouldBecomeFirstResponder = shouldBecomeFirstResponder
        self._scrollOffset = scrollOffset
        self.entryId = entryId
        self.onBlocksChange = onBlocksChange
        self.onTextViewReady = onTextViewReady
        self.onNewImageOverlayPositioned = onNewImageOverlayPositioned
        self.pendingFlyToAnimation = pendingFlyToAnimation
        self.topContentInset = topContentInset
        self.bottomContentInset = bottomContentInset
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> BlockEditorTextView {
        let textView = BlockEditorTextView()
        context.coordinator.parent = self
        context.coordinator.bind(to: textView)
        textView.onNewImageOverlayPositioned = onNewImageOverlayPositioned
        textView.pendingFlyToAnimation = pendingFlyToAnimation
        onTextViewReady?(textView)
        return textView
    }
    
    func updateUIView(_ uiView: BlockEditorTextView, context: Context) {
        context.coordinator.parent = self
        uiView.isEditable = isEditable
        uiView.isUserInteractionEnabled = true
        uiView.entryIdentifier = entryId
        // Apply custom top inset if provided (for EditorOverlay header space)
        if let topInset = topContentInset {
            uiView.setTopInset(topInset)
        }
        // Apply custom bottom inset if provided (for EditorOverlay footer space)
        if let bottomInset = bottomContentInset {
            uiView.setBottomInset(bottomInset)
        }
        // Update fly-to animation callback
        uiView.onNewImageOverlayPositioned = onNewImageOverlayPositioned
        // Only set pendingFlyToAnimation to true, never overwrite back to false
        // (the text view clears it itself after the animation completes)
        if pendingFlyToAnimation {
            uiView.pendingFlyToAnimation = true
        }
        context.coordinator.applyIfNeeded(blocks: blocks, imageMap: imageMap)
        context.coordinator.handleFirstResponderIfNeeded(textView: uiView)
    }
    
    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: BlockEditorRepresentable
        weak var textView: BlockEditorTextView?
        var bridge: BlockEditorBridge?
        private var notificationToken: NSObjectProtocol?
        private var metadataToken: NSObjectProtocol?
        private var pendingSnapshot: DispatchWorkItem?
        private var lastAppliedBlocks: [Block] = []
        
        init(parent: BlockEditorRepresentable) {
            self.parent = parent
            super.init()
        }
        
        deinit {
            if let token = notificationToken {
                NotificationCenter.default.removeObserver(token)
            }
            if let token = metadataToken {
                NotificationCenter.default.removeObserver(token)
            }
        }
        
        func bind(to textView: BlockEditorTextView) {
            self.textView = textView
            #if DEBUG
            dlog("🔧 Coordinator.bind - parent.isEditable: \(parent.isEditable)")
            #endif
            textView.isEditable = parent.isEditable
            textView.isUserInteractionEnabled = true
            textView.isSelectable = true
            textView.entryIdentifier = parent.entryId
            // Set coordinator as the scroll delegate to capture scroll events
            textView.scrollDelegate = self
            bridge = BlockEditorBridge(textView: textView)
            bridge?.apply(blocks: parent.blocks, imageMap: parent.imageMap)
            lastAppliedBlocks = parent.blocks
            #if DEBUG
            dlog("🔧 Coordinator.bind - textView.isEditable after: \(textView.isEditable), isSelectable: \(textView.isSelectable)")
            #endif
            
            notificationToken = NotificationCenter.default.addObserver(
                forName: UITextView.textDidChangeNotification,
                object: textView,
                queue: .main
            ) { [weak self] _ in
                self?.scheduleSnapshot()
            }
            
            metadataToken = NotificationCenter.default.addObserver(
                forName: .editorApplyPerBlockMetadata,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleMetadataNotification(notification)
            }
        }
        
        // MARK: - UIScrollViewDelegate
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let offsetY = scrollView.contentOffset.y
            parent.scrollOffset = max(0, offsetY)
        }
        
        func applyIfNeeded(blocks: [Block], imageMap: [UUID: UIImage]) {
            guard let bridge else { return }
            textView?.entryIdentifier = parent.entryId
            if bridge.isApplyingExternalUpdate {
                return
            }
            if lastAppliedBlocks == blocks {
                bridge.refreshImages(using: imageMap)
                return
            }
            bridge.apply(blocks: blocks, imageMap: imageMap)
            lastAppliedBlocks = blocks
        }
        
        func handleFirstResponderIfNeeded(textView: BlockEditorTextView) {
            guard parent.shouldBecomeFirstResponder else { return }
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
                if !self.isPlaceholderOnly(self.parent.blocks) {
                    textView.moveCaretToEndOfDocument()
                }
                self.parent.shouldBecomeFirstResponder = false
            }
        }

        private func isPlaceholderOnly(_ blocks: [Block]) -> Bool {
            let contentBlocks = blocks.filter { block in
                switch block.type {
                case .text(let text):
                    return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                case .imageText(_, _, let text):
                    return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || block.imageUrl != nil
                case .image:
                    return true
                case .spacer:
                    return false
                }
            }

            guard !contentBlocks.isEmpty else { return true }

            return contentBlocks.allSatisfy { block in
                switch block.type {
                case .text(let text):
                    return text.isPlaceholderText
                case .imageText(_, _, let text):
                    return text.isPlaceholderText && block.imageUrl == nil
                case .image:
                    return false
                case .spacer:
                    return false
                }
            }
        }
        
        private func scheduleSnapshot() {
            guard let bridge, !bridge.isApplyingExternalUpdate else { return }
            pendingSnapshot?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, let bridge = self.bridge else { return }
                let snapshot = bridge.snapshotBlocks()
                self.lastAppliedBlocks = snapshot
                if snapshot != self.parent.blocks {
                    self.parent.blocks = snapshot
                }
                self.parent.onBlocksChange?(snapshot)
            }
            pendingSnapshot = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
        }
        
        private func handleMetadataNotification(_ notification: Notification) {
            guard
                let entryId = parent.entryId,
                let userInfo = notification.userInfo
            else {
                return
            }
            
            // Handle both UUID and String for backwards compatibility
            let notifiedEntryID: UUID?
            if let uuidValue = userInfo["entryId"] as? UUID {
                notifiedEntryID = uuidValue
            } else if let stringValue = userInfo["entryId"] as? String {
                notifiedEntryID = UUID(uuidString: stringValue)
            } else {
                return
            }
            
            guard notifiedEntryID == entryId else { return }
            if isAnalysisStateOnlyNotification(userInfo) {
                return
            }
            scheduleSnapshot()
        }

        private func isAnalysisStateOnlyNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
            guard let blocks = userInfo["analyzedBlocks"] as? [[String: Any]], !blocks.isEmpty else {
                return false
            }

            return blocks.allSatisfy { block in
                guard block["isAnalyzing"] != nil else { return false }
                let nutritionKeys = [
                    "calories",
                    "protein",
                    "fat",
                    "carbs",
                    "fiber",
                    "sugar",
                    "sodium",
                    "weight"
                ]
                return nutritionKeys.allSatisfy { key in
                    guard let value = block[key] else { return true }
                    if value is NSNull { return true }
                    return false
                }
            }
        }
    }
}
