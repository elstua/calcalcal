import UIKit

@available(iOS 16.0, *)
struct BlockEditorConfiguration {
    var initialText: String = ""
}

@available(iOS 16.0, *)
final class BlockEditorTextView: UITextView {
    let blockContentStorage: BlockTextContentStorage
    let blockLayoutController: BlockTextLayoutController
    
    init(configuration: BlockEditorConfiguration = BlockEditorConfiguration()) {
        self.blockContentStorage = BlockTextContentStorage()
        self.blockLayoutController = BlockTextLayoutController(contentStorage: blockContentStorage)
        
        super.init(frame: .zero, textContainer: nil)
        
        guard let textLayoutManager = self.textLayoutManager else {
            fatalError("BlockEditorTextView requires TextKit 2 (UITextView.textLayoutManager must be available)")
        }
        
        textLayoutManager.replace(blockContentStorage)
        blockLayoutController.attach(to: textLayoutManager)
        
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        
        backgroundColor = .clear
        alwaysBounceVertical = true
        contentInsetAdjustmentBehavior = .automatic
        textDragInteraction?.isEnabled = true
        isScrollEnabled = true
        allowsEditingTextAttributes = false
        smartInsertDeleteType = .yes
        spellCheckingType = .yes
        autocorrectionType = .yes
        
        blockContentStorage.applyInitialText(configuration.initialText)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateTextIfNeeded(_ text: String) {
        blockContentStorage.updateTextIfNeeded(text)
    }
}

