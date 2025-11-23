import SwiftUI
import UIKit

struct DiaryEditorCard: View {
    let entry: DiaryEntry
    var height: CGFloat
    var cornerRadius: CGFloat
    var showShadow: Bool
    var useExternalDecoration: Bool
    var onAddImage: (() -> Void)?
    var onTap: (() -> Void)?
    var imageMap: [UUID: UIImage]
    var isEditable: Bool
    var forceExpanded: Bool
    var onBlocksChange: (([Block]) -> Void)?
    var overrideTotalCalories: Int?
    private var externalBlocks: Binding<[Block]>?
    @Binding private var shouldBecomeFirstResponder: Bool
    
    init(entry: DiaryEntry,
         height: CGFloat = 550,
         cornerRadius: CGFloat = 24,
         showShadow: Bool = false,
         useExternalDecoration: Bool = true,
         onAddImage: (() -> Void)? = nil,
         onTap: (() -> Void)? = nil,
         imageMap: [UUID: UIImage] = [:],
         isEditable: Bool = true,
         shouldBecomeFirstResponder: Binding<Bool> = .constant(false),
         forceExpanded: Bool = true,
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
    }
    
    var body: some View {
        BigEntryBlock(
            entry: entry,
            height: height,
            cornerRadius: cornerRadius,
            showShadow: showShadow,
            useExternalDecoration: useExternalDecoration,
            onAddImage: onAddImage,
            onTap: onTap,
            imageMap: imageMap,
            isEditable: isEditable,
            shouldBecomeFirstResponder: $shouldBecomeFirstResponder,
            forceExpanded: forceExpanded,
            onBlocksChange: onBlocksChange,
            overrideTotalCalories: overrideTotalCalories,
            externalBlocks: externalBlocks
        )
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}






