import SwiftUI
import Foundation
import UIKit


// MARK: - DiaryEntry Model (for preview/demo)

struct BigEntryBlock: View {
    let entry: DiaryEntry
    /// Optional fixed height. When nil, the view expands to fill available space.
    var height: CGFloat? = nil
    var cornerRadius: CGFloat = 24
    var showShadow: Bool = true
    var useExternalDecoration: Bool = false
    var onAddImage: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil
    // For now, imageMap is empty; can be extended for real images
    var imageMap: [UUID: UIImage] = [:]
    var isEditable: Bool = false
    @Binding var shouldBecomeFirstResponder: Bool
    var forceExpanded: Bool = false
    var onBlocksChange: (([Block]) -> Void)? = nil
    // Optional override for displaying totals while editing/live-updating
    var overrideTotalCalories: Int? = nil
    
    // When provided, this binding will be used as the source of truth
    // for the editor content to keep multiple views in perfect sync.
    var externalBlocks: Binding<[Block]>? = nil
    @State private var internalBlocks: [Block]
    @State private var hydratedImageMap: [UUID: UIImage] = [:]
    private var effectiveImageMap: [UUID: UIImage] {
        var merged = imageMap
        for (k, v) in hydratedImageMap { merged[k] = v }
        return merged
    }
    private var effectiveBlocks: Binding<[Block]> {
        if let externalBlocks { return externalBlocks }
        return $internalBlocks
    }
    
    init(entry: DiaryEntry,
         height: CGFloat? = nil,
         cornerRadius: CGFloat = 24,
         showShadow: Bool = true,
         useExternalDecoration: Bool = false,
         onAddImage: (() -> Void)? = nil,
         onTap: (() -> Void)? = nil,
         imageMap: [UUID: UIImage] = [:],
         isEditable: Bool = false,
         shouldBecomeFirstResponder: Binding<Bool> = .constant(false),
         forceExpanded: Bool = false,
         onBlocksChange: (([Block]) -> Void)? = nil,
         overrideTotalCalories: Int? = nil,
         externalBlocks: Binding<[Block]>? = nil) {
        self.entry = entry
        self.height = height
        self.cornerRadius = cornerRadius
        self.showShadow = showShadow
        self.useExternalDecoration = useExternalDecoration
        self.onAddImage = onAddImage
        self.onTap = onTap
        self.imageMap = imageMap
        self.isEditable = isEditable
        self._shouldBecomeFirstResponder = shouldBecomeFirstResponder
        self.forceExpanded = forceExpanded
        self.onBlocksChange = onBlocksChange
        self.overrideTotalCalories = overrideTotalCalories
        self.externalBlocks = externalBlocks
        _internalBlocks = State(initialValue: entry.blocks.withStableIdsAndChangeTracking())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with date
            HStack {
                Text(formattedDate(entry.date))
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding([.top, .horizontal])
            
            // Always show the full editor
            BlockEditorRepresentable(
                blocks: effectiveBlocks,
                imageMap: effectiveImageMap,
                isEditable: isEditable,
                shouldBecomeFirstResponder: $shouldBecomeFirstResponder,
                entryId: entry.id,
                onBlocksChange: { newBlocks in
                    self.effectiveBlocks.wrappedValue = newBlocks
                    self.onBlocksChange?(newBlocks)
                }
            )
            .frame(maxHeight: .infinity)
            .padding(.horizontal)
            
            // Footer
            EntryFooterView(
                blocks: effectiveBlocks.wrappedValue,
                remoteTotalCalories: overrideTotalCalories ?? entry.totalCalories,
                onAddImage: { onAddImage?() }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(useExternalDecoration ? Color.clear : Color.white)
        .cornerRadius(useExternalDecoration ? 0 : cornerRadius)
        .shadow(color: (useExternalDecoration || !showShadow) ? .clear : Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        // Only add tap gesture when onTap is provided AND editing is disabled.
        // When isEditable is true, we must NOT add a tap gesture because it would
        // intercept taps meant for the UITextView and prevent text editing.
        .modifier(ConditionalTapGesture(isEnabled: onTap != nil && !isEditable, action: { onTap?() }))
        // Keep internal editor blocks in sync with external model
        .onChange(of: entry.blocks) { newValue in
            // Only drive internal state if we're not using an external binding
            if externalBlocks == nil {
                self.internalBlocks = newValue.withStableIdsAndChangeTracking()
            }
            hydrateImages(for: newValue)
        }
        // Do not force full refresh; rely on stableId-aware diffs to prevent state bleed
        .id(entry.id)
        .onAppear {
            hydrateImages(for: entry.blocks)
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
}

// MARK: - Image hydration
extension BigEntryBlock {
    private func hydrateImages(for blocks: [Block]) {
        for block in blocks {
            switch block.type {
            case .imageText(_, let ref, _):
                if hydratedImageMap[ref] != nil { continue }
                if let url = block.imageUrl, !url.isEmpty {
                    if let cached = ImageCache.shared.imageIfCached(for: url) {
                        hydratedImageMap[ref] = cached
                    } else {
                        Task.detached { @MainActor in
                            if let fetched = await ImageCache.shared.fetch(url) {
                                hydratedImageMap[ref] = fetched
                            }
                        }
                    }
                } else {
                    if let cached = ImageCache.shared.localImage(ref: ref, legacyEntryId: entry.id) {
                        hydratedImageMap[ref] = cached
                    }
                }
            default:
                continue
            }
        }
    }
}



// MARK: - Preview

/// A view modifier that conditionally applies a tap gesture.
/// When disabled, no gesture is added so taps pass through to child views (like UITextView).
struct ConditionalTapGesture: ViewModifier {
    let isEnabled: Bool
    let action: () -> Void
    
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .contentShape(Rectangle())
                .onTapGesture { action() }
        } else {
            content
        }
    }
}

struct BigEntryBlock_Previews: PreviewProvider {
    static var previews: some View {
        let blocks = [
            Block(type: .text("Breakfast: 2 eggs, 1 toast, 1 orange juice"), calorieData: "320"),
            Block(type: .text("Lunch: Chicken salad, 1 apple"), calorieData: "410"),
            Block(type: .text("Snack: Protein bar"), calorieData: "180")
        ]
        let entry = DiaryEntry(
            id: UUID(),
            date: Date(),
            blocks: blocks,
            totalCalories: 910,
            lastModified: Date(),
            aiGeneratedSummary: "Breakfast: eggs, toast, juice. Lunch: salad, apple. Snack: bar."
        )
        VStack {
            BigEntryBlock(entry: entry, isEditable: true)
                .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}
