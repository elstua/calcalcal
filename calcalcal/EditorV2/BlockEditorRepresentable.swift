import SwiftUI
import UIKit

struct BlockEditorRepresentable: UIViewRepresentable {
    @Binding var blocks: [Block]
    var imageMap: [UUID: UIImage]
    var isEditable: Bool
    @Binding var shouldBecomeFirstResponder: Bool
    var entryId: UUID?
    var onBlocksChange: (([Block]) -> Void)?
    var onTextViewReady: ((BlockEditorTextView) -> Void)?
    
    init(blocks: Binding<[Block]>,
         imageMap: [UUID: UIImage] = [:],
         isEditable: Bool = true,
         shouldBecomeFirstResponder: Binding<Bool> = .constant(false),
         entryId: UUID? = nil,
         onBlocksChange: (([Block]) -> Void)? = nil,
         onTextViewReady: ((BlockEditorTextView) -> Void)? = nil) {
        self._blocks = blocks
        self.imageMap = imageMap
        self.isEditable = isEditable
        self._shouldBecomeFirstResponder = shouldBecomeFirstResponder
        self.entryId = entryId
        self.onBlocksChange = onBlocksChange
        self.onTextViewReady = onTextViewReady
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> BlockEditorTextView {
        let textView = BlockEditorTextView()
        context.coordinator.parent = self
        context.coordinator.bind(to: textView)
        onTextViewReady?(textView)
        return textView
    }
    
    func updateUIView(_ uiView: BlockEditorTextView, context: Context) {
        context.coordinator.parent = self
//        #if DEBUG
//        print("🔧 BlockEditorRepresentable.updateUIView - isEditable: \(isEditable), uiView.isEditable before: \(uiView.isEditable)")
//        #endif
        uiView.isEditable = isEditable
        uiView.isUserInteractionEnabled = true // Ensure interaction is enabled
//        #if DEBUG
//        print("🔧 BlockEditorRepresentable.updateUIView - uiView.isEditable after: \(uiView.isEditable)")
//        #endif
        uiView.entryIdentifier = entryId
        context.coordinator.applyIfNeeded(blocks: blocks, imageMap: imageMap)
        context.coordinator.handleFirstResponderIfNeeded(textView: uiView)
    }
    
    final class Coordinator {
        var parent: BlockEditorRepresentable
        weak var textView: BlockEditorTextView?
        var bridge: BlockEditorBridge?
        private var notificationToken: NSObjectProtocol?
        private var metadataToken: NSObjectProtocol?
        private var pendingSnapshot: DispatchWorkItem?
        private var lastAppliedBlocks: [Block] = []
        
        init(parent: BlockEditorRepresentable) {
            self.parent = parent
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
            print("🔧 Coordinator.bind - parent.isEditable: \(parent.isEditable)")
            #endif
            textView.isEditable = parent.isEditable
            textView.isUserInteractionEnabled = true
            textView.isSelectable = true
            textView.entryIdentifier = parent.entryId
            bridge = BlockEditorBridge(textView: textView)
            bridge?.apply(blocks: parent.blocks, imageMap: parent.imageMap)
            lastAppliedBlocks = parent.blocks
            #if DEBUG
            print("🔧 Coordinator.bind - textView.isEditable after: \(textView.isEditable), isSelectable: \(textView.isSelectable)")
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
                self.parent.shouldBecomeFirstResponder = false
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
            scheduleSnapshot()
        }
    }
}
