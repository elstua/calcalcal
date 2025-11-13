import SwiftUI
import Foundation
import UIKit


// MARK: - DiaryEntry Model (for preview/demo)

struct BigEntryBlock: View {
    let entry: DiaryEntry
    var height: CGFloat = 550
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
    private var effectiveBlocks: Binding<[Block]> {
        if let externalBlocks { return externalBlocks }
        return $internalBlocks
    }
    
    init(entry: DiaryEntry,
         height: CGFloat = 550,
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
            UnifiedTextEditor(
                blocks: effectiveBlocks,
                imageMap: imageMap,
                isEditable: isEditable,
                shouldBecomeFirstResponder: $shouldBecomeFirstResponder,
                entryId: entry.id
            )
                .blockSpacing(20)
                .onBlocksChange { newBlocks in
                    // Keep state (external or internal) and bubble up to parent
                    self.effectiveBlocks.wrappedValue = newBlocks
                    self.onBlocksChange?(newBlocks)
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal)
            
            Spacer(minLength: 0)
            
            // Footer
            EntryFooterView(
                calorieSummary: "\((overrideTotalCalories ?? entry.totalCalories).map { String($0) } ?? "…") kcal",
                onAddImage: { onAddImage?() }
            )
            .padding(.bottom, 8)
        }
        .frame(height: forceExpanded ? nil : height)
        .background(useExternalDecoration ? Color.clear : Color.white)
        .cornerRadius(useExternalDecoration ? 0 : cornerRadius)
        .shadow(color: (useExternalDecoration || !showShadow) ? .clear : Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        .onTapGesture { onTap?() }
        // Keep internal editor blocks in sync with external model
        .onChange(of: entry.blocks) { newValue in
            // Only drive internal state if we're not using an external binding
            if externalBlocks == nil {
                self.internalBlocks = newValue.withStableIdsAndChangeTracking()
            }
        }
        // Do not force full refresh; rely on stableId-aware diffs to prevent state bleed
        .id(entry.id)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
}



// MARK: - Preview

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
