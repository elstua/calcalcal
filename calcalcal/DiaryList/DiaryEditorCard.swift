import SwiftUI
import UIKit

struct DiaryEditorCard: View {
    enum DisplayMode {
        case fullEditor
        case compactSummary
    }
    
    let entry: DiaryEntry
    /// Optional fixed height. When nil, the view expands to fill available space.
    var height: CGFloat?
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
    var onScrollOffsetChange: ((CGFloat) -> Void)?
    var topContentInset: CGFloat?
    private var externalBlocks: Binding<[Block]>?
    @Binding private var shouldBecomeFirstResponder: Bool
    var displayMode: DisplayMode
    

    
    init(entry: DiaryEntry,
         height: CGFloat? = nil,
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
         onScrollOffsetChange: ((CGFloat) -> Void)? = nil,
         topContentInset: CGFloat? = nil,
         externalBlocks: Binding<[Block]>? = nil,
         displayMode: DisplayMode = .fullEditor) {
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
        self.onScrollOffsetChange = onScrollOffsetChange
        self.topContentInset = topContentInset
        self.externalBlocks = externalBlocks
        self.displayMode = displayMode
    }
    
    var body: some View {
        Group {
            switch displayMode {
            case .fullEditor:
                fullEditorCard
            case .compactSummary:
                compactSummaryCard
            }
        }
    }
    
    @ViewBuilder
    private var fullEditorCard: some View {
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
            onScrollOffsetChange: onScrollOffsetChange,
            topContentInset: topContentInset,
            externalBlocks: externalBlocks
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    @ViewBuilder
    private var compactSummaryCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(dayNumberString(entry.date))
                .font(.title3.bold())
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
                .background(Color.gray.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                summaryTextView()
                Text("\(resolvedCaloriesText()) kcal")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(useExternalDecoration ? Color.clear : Color(.systemBackground))
        .cornerRadius(useExternalDecoration ? 0 : cornerRadius)
        .shadow(color: (useExternalDecoration || !showShadow) ? .clear : Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .top)
    }
    
    @ViewBuilder
    private func summaryTextView() -> some View {
        let display = summaryDisplayText()
        if display.isPlaceholder {
            // Show placeholder in textTertiary (not italic)
            Text(display.text)
                .font(.body)
                .foregroundColor(DSColors.textTertiary)
                .lineLimit(2)
        } else if display.italic {
            Text(display.text)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .italic()
        } else {
            Text(display.text)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
    }
    
    private func summaryDisplayText() -> (text: String, italic: Bool, isPlaceholder: Bool) {
        // First check if we have an AI-generated summary
        if let summary = entry.aiGeneratedSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !summary.isEmpty {
            return (summary, false, false)
        }

        // Filter to only text-bearing blocks
        let textBlocks = entry.blocks.compactMap { block -> (text: String, isPlaceholder: Bool)? in
            switch block.type {
            case .text(let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return nil }
                return (trimmed, trimmed.isPlaceholderText)
            case .imageText(_, _, let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return nil }
                return (trimmed, trimmed.isPlaceholderText)
            case .image, .spacer:
                return nil
            }
        }

        // If we have content blocks
        if !textBlocks.isEmpty {
            // Check if the last block is a placeholder
            if let lastBlock = textBlocks.last, lastBlock.isPlaceholder {
                // If we have other content before the placeholder, show placeholder in gray
                if textBlocks.count > 1 {
                    return (lastBlock.text.strippingPlaceholderMarker, false, true)
                } else {
                    // Only placeholder exists - show it as placeholder
                    return (lastBlock.text.strippingPlaceholderMarker, true, true)
                }
            }

            // Return the first non-placeholder block
            if let firstBlock = textBlocks.first(where: { !$0.isPlaceholder }) {
                return (firstBlock.text, false, false)
            }
        }

        return ("No entry yet. Start logging your food!", true, false)
    }
    
    private func resolvedCaloriesText() -> String {
        if let overrideTotalCalories {
            return String(overrideTotalCalories)
        }
        if let total = entry.totalCalories {
            return String(total)
        }
        return "…"
    }
    
    private func dayNumberString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}