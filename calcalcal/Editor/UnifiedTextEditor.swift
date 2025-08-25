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
    
    init(
        blocks: Binding<[Block]>,
        imageMap: [UUID: UIImage] = [:],
        onBlocksChange: (([Block]) -> Void)? = nil,
        defaultBlockSpacing: CGFloat = 32,
        isEditable: Bool = true,
        shouldBecomeFirstResponder: Binding<Bool> = .constant(false)
    ) {
        self._blocks = blocks
        self.imageMap = imageMap
        self.onBlocksChange = onBlocksChange
        self.defaultBlockSpacing = defaultBlockSpacing
        self.isEditable = isEditable
        self._shouldBecomeFirstResponder = shouldBecomeFirstResponder
    }
    
    func makeUIView(context: Context) -> UnifiedTextView {
        let textView = UnifiedTextView()
        textView.defaultBlockSpacing = defaultBlockSpacing
        textView.blocks = blocks
        textView.imageMap = imageMap
        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        print("[makeUIView] Initial blocks: \(blocks)")
        textView.renderBlocks()
        print("[makeUIView] Called renderBlocks()")
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

        // Only update content if the change is external
        guard textView.blocks != blocks else {
            if shouldBecomeFirstResponder {
                DispatchQueue.main.async {
                    textView.becomeFirstResponder()
                    self.shouldBecomeFirstResponder = false
                }
            }
            return
        }

        // Compute fine-grained diffs to avoid full re-render when only metadata changed
        let oldBlocks = textView.blocks
        let newBlocks = blocks

        // If count changed, prefer full rebuild to ensure storage matches
        if oldBlocks.count != newBlocks.count {
            textView.blocks = newBlocks
            textView.renderBlocks()
            if shouldBecomeFirstResponder {
                DispatchQueue.main.async {
                    textView.becomeFirstResponder()
                    self.shouldBecomeFirstResponder = false
                }
            }
            return
        }
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
            if old == new { continue }
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
            // Apply metadata-only updates for labels/backgrounds without touching text
            textView.isProgrammaticUpdate = true
            for i in metadataChangeIndices {
                if i < newBlocks.count {
                    textView.updateBlockMetadata(at: i, calorieData: newBlocks[i].calorieData, nutrition: newBlocks[i].nutrition)
                }
            }
            textView.blocks = newBlocks
            textView.isProgrammaticUpdate = false
            if shouldBecomeFirstResponder {
                DispatchQueue.main.async {
                    textView.becomeFirstResponder()
                    self.shouldBecomeFirstResponder = false
                }
            }
            return
        }

        // Apply content changes - partial if small, full otherwise
        print("[updateUIView] Applying content changes; indices=\(contentChangeIndices)")
        textView.isProgrammaticUpdate = true
        textView.blocks = newBlocks
        if !contentChangeIndices.isEmpty && contentChangeIndices.count <= 2 {
            textView.renderBlocks(affectedBlockIndices: contentChangeIndices)
        } else {
            textView.renderBlocks()
        }
        textView.isProgrammaticUpdate = false
        print("[updateUIView] Called renderBlocks()")
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
        while location < nsString.length {
            var paragraphStart = 0
            var paragraphEnd = 0
            var contentsEnd = 0
            nsString.getParagraphStart(&paragraphStart, end: &paragraphEnd, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))
            let paragraphRange = NSRange(location: paragraphStart, length: paragraphEnd - paragraphStart)
            let paragraphText = nsString.substring(with: paragraphRange).trimmingCharacters(in: .whitespacesAndNewlines)

            if let metadata = textView.unifiedContentStorage.blockMetadata(at: paragraphStart) {
                switch metadata.blockType {
                case .text:
                    var nutrition: NutritionData? = nil
                    if let data = metadata.nutritionJSON {
                        nutrition = try? JSONDecoder().decode(NutritionData.self, from: data)
                    }
                    reconstructed.append(Block(type: .text(paragraphText), calorieData: metadata.calorieData, nutrition: nutrition))
                case .imageText:
                    if let imageRef = metadata.imageReference,
                       let image = textView.imageMap[imageRef],
                       let data = image.pngData() {
                        var nutrition: NutritionData? = nil
                        if let ndata = metadata.nutritionJSON {
                            nutrition = try? JSONDecoder().decode(NutritionData.self, from: ndata)
                        }
                        reconstructed.append(Block(type: .imageText(data, imageRef, paragraphText), calorieData: metadata.calorieData, nutrition: nutrition))
                    }
                case .spacer:
                    reconstructed.append(Block(type: .spacer, calorieData: nil, nutrition: nil))
                }
            } else {
                // Fallback: treat as a plain text block when no metadata present
                reconstructed.append(Block(type: .text(paragraphText), calorieData: nil, nutrition: nil))
            }

            location = paragraphEnd
        }

        if reconstructed != blocks {
            DispatchQueue.main.async {
                self.blocks = reconstructed
                self.onBlocksChange?(reconstructed)
            }
        }
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: UnifiedTextEditor
        
        init(_ parent: UnifiedTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            guard let unifiedTextView = textView as? UnifiedTextView else { return }
            unifiedTextView.textViewDidChange(textView)
            parent.updateBlocksFromTextStorage(unifiedTextView)
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