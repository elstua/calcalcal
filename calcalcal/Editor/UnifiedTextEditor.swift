import SwiftUI
import UIKit

/// SwiftUI wrapper for the unified text editor
struct UnifiedTextEditor: UIViewRepresentable {
    
    @Binding var blocks: [Block]
    var imageMap: [UUID: UIImage] = [:]
    var onBlocksChange: (([Block]) -> Void)?
    var defaultBlockSpacing: CGFloat = 32
    var isEditable: Bool = true
    @Binding var shouldBecomeFirstResponder: Bool
    var entryId: UUID? = nil
    
    init(
        blocks: Binding<[Block]>,
        imageMap: [UUID: UIImage] = [:],
        onBlocksChange: (([Block]) -> Void)? = nil,
        defaultBlockSpacing: CGFloat = 32,
        isEditable: Bool = true,
        shouldBecomeFirstResponder: Binding<Bool> = .constant(false),
        entryId: UUID? = nil
    ) {
        self._blocks = blocks
        self.imageMap = imageMap
        self.onBlocksChange = onBlocksChange
        self.defaultBlockSpacing = defaultBlockSpacing
        self.isEditable = isEditable
        self._shouldBecomeFirstResponder = shouldBecomeFirstResponder
        self.entryId = entryId
    }
    
    func makeUIView(context: Context) -> UnifiedTextView {
        let textView = UnifiedTextView()
        textView.defaultBlockSpacing = defaultBlockSpacing
        textView.blocks = blocks
        textView.imageMap = imageMap
        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        textView.entryId = entryId
        print("[makeUIView] Initial blocks: \(blocks)")
        print("[makeUIView] DEBUG: textView=\(textView), entry context unknown at this level")
        textView.renderBlocks()
        print("[makeUIView] Called renderBlocks()")
        // Ensure initial visuals appear even before the first layout pass settles
        DispatchQueue.main.async {
            textView.updateExclusionPaths()
            textView.updateImageViews()
            textView.updateBlockBackgroundViews()
            textView.setNeedsDisplay()
        }
        if shouldBecomeFirstResponder {
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
                self.shouldBecomeFirstResponder = false
            }
        }
        return textView
    }
    
    func updateUIView(_ textView: UnifiedTextView, context: Context) {
        // Always keep ancillary props in sync
        textView.imageMap = imageMap
        textView.isEditable = isEditable
        textView.entryId = entryId

        // Only update content if the change is external; if user recently edited, queue external update
        guard textView.blocks != blocks else {
            if shouldBecomeFirstResponder {
                DispatchQueue.main.async {
                    textView.becomeFirstResponder()
                    self.shouldBecomeFirstResponder = false
                }
            }
            return
        }

        // Compute fine-grained diffs to avoid unnecessary full re-render
        let oldBlocks = textView.blocks
        let newBlocks = blocks
        let count = max(oldBlocks.count, newBlocks.count)
        var contentChangeIndices: [Int] = []
        var metadataChangeIndices: [Int] = []

        func textOf(_ block: Block) -> String? {
            switch block.type {
            case .text(let t): return t
            case .imageText(_, _, let t): return t
            default: return nil
            }
        }

        for i in 0..<count {
            let old: Block? = i < oldBlocks.count ? oldBlocks[i] : nil
            let new: Block? = i < newBlocks.count ? newBlocks[i] : nil
            // Prefer stable identity first
            if let o = old, let n = new, o.id == n.id, o == n { continue }
            guard let old = old, let new = new else {
                // insertion/deletion => content change
                contentChangeIndices.append(i)
                continue
            }
            // Compare type and visible text content
            let oldTypeText = textOf(old)
            let newTypeText = textOf(new)
            let oldIsTextual = oldTypeText != nil
            let newIsTextual = newTypeText != nil
            if oldIsTextual != newIsTextual {
                contentChangeIndices.append(i)
                continue
            }
            // If textual and text differs => content change
            if let ot = oldTypeText, let nt = newTypeText, ot != nt {
                contentChangeIndices.append(i)
                continue
            }
            // If blockType differs (e.g., imageText -> text)
            switch (old.type, new.type) {
            case (.text, .text): break
            case (.imageText, .imageText): break
            case (.image, .image): break
            case (.spacer, .spacer): break
            default:
                contentChangeIndices.append(i)
                continue
            }
            // Otherwise, treat as metadata-only change
            metadataChangeIndices.append(i)
        }

        if !metadataChangeIndices.isEmpty && contentChangeIndices.isEmpty {
            // Metadata-only differences: prefer device metadata (view) as source of truth.
            // Merge view metadata into the SwiftUI model to keep them in sync.
            var merged = newBlocks
            for i in metadataChangeIndices {
                guard i < merged.count, let blockRange = textView.rangeForBlock(at: i),
                      let meta = textView.unifiedContentStorage.blockMetadata(at: blockRange.location) else { continue }
                // Pull latest metadata from the view
                merged[i].calorieData = meta.calorieData
                if let data = meta.nutritionJSON {
                    let decoded = try? JSONDecoder().decode(NutritionData.self, from: data)
                    merged[i].nutrition = decoded
                } else {
                    merged[i].nutrition = nil
                }
            }
            // Sync local snapshot
            textView.isProgrammaticUpdate = true
            textView.blocks = merged
            textView.isProgrammaticUpdate = false
            // Update visuals
            textView.updateBlockBackgroundViews()
            textView.setNeedsDisplay()
            // Propagate merged metadata back up if it differs
            if merged != blocks {
                DispatchQueue.main.async {
                    self.onBlocksChange?(merged)
                }
            }
            if shouldBecomeFirstResponder {
                DispatchQueue.main.async {
                    textView.becomeFirstResponder()
                    self.shouldBecomeFirstResponder = false
                }
            }
            return
        }

        // Apply content changes; use full rebuild path for safety (image/text layout is complex)
        #if DEBUG
        print("[updateUIView] Applying content changes; indices=\(contentChangeIndices)")
        #endif
        // Defer external updates during active typing/composition
        let now2 = CACurrentMediaTime()
        if now2 - textView.lastUserEditAt < 0.6 || textView.markedTextRange != nil {
            textView.pendingExternalBlocks = newBlocks
            textView.externalBlocksApplyWorkItem?.cancel()
            let work = DispatchWorkItem { [weak textView] in
                // When applying, preserve caret to prevent jump-to-zero
                let caret = textView?.selectedRange.location ?? 0
                textView?.isProgrammaticUpdate = true
                textView?.blocks = newBlocks
                textView?.renderBlocks(restoreCaretTo: caret)
                textView?.isProgrammaticUpdate = false
                textView?.pendingExternalBlocks = nil
            }
            textView.externalBlocksApplyWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
            return
        }
        // Before rendering, merge any existing on-device metadata into incoming model
        var mergedBlocks = newBlocks
        // Try to preserve metadata even when content changes
        for i in 0..<min(textView.blocks.count, mergedBlocks.count) {
            // Skip if incoming already has metadata
            if mergedBlocks[i].calorieData != nil && mergedBlocks[i].nutrition != nil { continue }
            if let range = textView.rangeForBlock(at: i),
               let meta = textView.unifiedContentStorage.blockMetadata(at: range.location) {
                if mergedBlocks[i].calorieData == nil {
                    mergedBlocks[i].calorieData = meta.calorieData
                }
                if mergedBlocks[i].nutrition == nil, let data = meta.nutritionJSON {
                    mergedBlocks[i].nutrition = try? JSONDecoder().decode(NutritionData.self, from: data)
                }
            }
        }
        textView.isProgrammaticUpdate = true
        textView.blocks = mergedBlocks
        let caretLocation = textView.selectedRange.location
        textView.renderBlocks(restoreCaretTo: caretLocation)
        textView.isProgrammaticUpdate = false
        #if DEBUG
        print("[updateUIView] Called renderBlocks()")
        #endif
        if shouldBecomeFirstResponder {
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
                self.shouldBecomeFirstResponder = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// Syncs the blocks array from the UITextView's content and metadata
    func updateBlocksFromTextStorage(_ textView: UnifiedTextView) {
        // Reconstruct blocks from the UITextView's text storage and our metadata
        let nsString = textView.textStorage.string as NSString
        var reconstructed: [Block] = []
        var location = 0
        var paragraphIndex = 0
        while location < nsString.length {
            var paragraphStart = 0
            var paragraphEnd = 0
            var contentsEnd = 0
            nsString.getParagraphStart(&paragraphStart, end: &paragraphEnd, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))
            let paragraphRange = NSRange(location: paragraphStart, length: paragraphEnd - paragraphStart)
            // Preserve user-entered spaces; only strip a single trailing newline if present
            var paragraphText = nsString.substring(with: paragraphRange)
            if paragraphText.hasSuffix("\n") {
                paragraphText.removeLast()
            }

            if let metadata = textView.unifiedContentStorage.blockMetadata(at: paragraphStart) {
                switch metadata.blockType {
                case .text:
                    var nutrition: NutritionData? = nil
                    if let data = metadata.nutritionJSON {
                        nutrition = try? JSONDecoder().decode(NutritionData.self, from: data)
                    }
                    var block = Block(type: .text(paragraphText), calorieData: metadata.calorieData, nutrition: nutrition)
                    // Preserve image-related metadata even for text paragraphs to avoid losing URLs when rebuilding
                    if paragraphIndex < blocks.count {
                        block.imageUrl = blocks[paragraphIndex].imageUrl
                        block.imageObjectKey = blocks[paragraphIndex].imageObjectKey
                    }
                    reconstructed.append(block)
                case .imageText:
                    if let imageRef = metadata.imageReference {
                        var nutrition: NutritionData? = nil
                        if let ndata = metadata.nutritionJSON {
                            nutrition = try? JSONDecoder().decode(NutritionData.self, from: ndata)
                        }
                        if let image = textView.imageMap[imageRef], let data = image.pngData() {
                            var block = Block(type: .imageText(data, imageRef, paragraphText), calorieData: metadata.calorieData, nutrition: nutrition)
                            // Preserve URL/objectKey if they existed in the previous model snapshot
                            if paragraphIndex < blocks.count {
                                block.imageUrl = blocks[paragraphIndex].imageUrl
                                block.imageObjectKey = blocks[paragraphIndex].imageObjectKey
                            }
                            reconstructed.append(block)
                        } else {
                            // Preserve image-text block even when image isn't hydrated yet
                            var block = Block(type: .imageText(Data(), imageRef, paragraphText), calorieData: metadata.calorieData, nutrition: nutrition)
                            if paragraphIndex < blocks.count {
                                block.imageUrl = blocks[paragraphIndex].imageUrl
                                block.imageObjectKey = blocks[paragraphIndex].imageObjectKey
                            }
                            reconstructed.append(block)
                        }
                    } else {
                        // Defensive fallback: treat as text while preserving metadata
                        var nutrition: NutritionData? = nil
                        if let data = metadata.nutritionJSON {
                            nutrition = try? JSONDecoder().decode(NutritionData.self, from: data)
                        }
                        var block = Block(type: .text(paragraphText), calorieData: metadata.calorieData, nutrition: nutrition)
                        if paragraphIndex < blocks.count {
                            block.imageUrl = blocks[paragraphIndex].imageUrl
                            block.imageObjectKey = blocks[paragraphIndex].imageObjectKey
                        }
                        reconstructed.append(block)
                    }
                case .spacer:
                    reconstructed.append(Block(type: .spacer, calorieData: nil, nutrition: nil))
                }
                paragraphIndex += 1
            } else {
                // Fallback: treat as a plain text block when no metadata present
                var block = Block(type: .text(paragraphText), calorieData: nil, nutrition: nil)
                if paragraphIndex < blocks.count {
                    block.imageUrl = blocks[paragraphIndex].imageUrl
                    block.imageObjectKey = blocks[paragraphIndex].imageObjectKey
                }
                reconstructed.append(block)
                paragraphIndex += 1
            }

            location = paragraphEnd
        }

        if reconstructed != blocks {
            // Keep the UITextView's local snapshot in sync to avoid re-render churn
            textView.blocks = reconstructed
            DispatchQueue.main.async {
                self.blocks = reconstructed
                self.onBlocksChange?(reconstructed)
            }
        }
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: UnifiedTextEditor
        private var debounceWorkItem: DispatchWorkItem?
        private let debounceInterval: TimeInterval = 0.12
        
        init(_ parent: UnifiedTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            guard textView is UnifiedTextView else { return }
            // Skip updates while the user is composing text (IME)
            if textView.markedTextRange != nil { return }
            // Debounce parsing and model updates to reduce churn
            debounceWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self, weak tv = textView] in
                guard let self = self, let tv = tv as? UnifiedTextView else { return }
                if tv.markedTextRange != nil { return }
                self.parent.updateBlocksFromTextStorage(tv)
            }
            debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                #if DEBUG
                print("↩️ [Coordinator] Enter pressed – committing paragraph")
                #endif
                DispatchQueue.main.async {
                    #if DEBUG
                    print("📣 [Coordinator] Posting editorParagraphCommitted notification")
                    #endif
                    NotificationCenter.default.post(name: .editorParagraphCommitted, object: nil)
                }
                return true
            }
            return true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            #if DEBUG
            print("✅ [Coordinator] textViewDidEndEditing -> saved paragraph edited notification")
            #endif
            NotificationCenter.default.post(name: .editorSavedParagraphEdited, object: nil)
        }
    }
}

// MARK: - View Modifiers

extension UnifiedTextEditor {
    
    func blockSpacing(_ spacing: CGFloat) -> UnifiedTextEditor {
        var editor = self
        editor.defaultBlockSpacing = spacing
        return editor
    }
    
    func onBlocksChange(_ action: @escaping ([Block]) -> Void) -> UnifiedTextEditor {
        var editor = self
        editor.onBlocksChange = action
        return editor
    }
} 
