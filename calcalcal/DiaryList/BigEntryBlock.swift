import SwiftUI
import UIKit


// MARK: - DiaryEntry Model (for preview/demo)
struct DiaryEntry {
    let id: UUID
    let date: Date
    var blocks: [Block]
    var totalCalories: Int?
    var lastModified: Date
    var aiGeneratedSummary: String?
}

struct BigEntryBlock: View {
    let entry: DiaryEntry
    var height: CGFloat = 550
    var cornerRadius: CGFloat = 24
    var showShadow: Bool = true
    var onAddImage: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil
    // For now, imageMap is empty; can be extended for real images
    var imageMap: [UUID: UIImage] = [:]
    
    @State private var isExpanded: Bool = false
    @State private var blocks: [Block]
    
    init(entry: DiaryEntry,
         height: CGFloat = 550,
         cornerRadius: CGFloat = 24,
         showShadow: Bool = true,
         onAddImage: (() -> Void)? = nil,
         onTap: (() -> Void)? = nil,
         imageMap: [UUID: UIImage] = [:]) {
        self.entry = entry
        self.height = height
        self.cornerRadius = cornerRadius
        self.showShadow = showShadow
        self.onAddImage = onAddImage
        self.onTap = onTap
        self.imageMap = imageMap
        _blocks = State(initialValue: entry.blocks)
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
            
            if isExpanded {
                // Expanded: show full editor
                UnifiedTextEditor(blocks: $blocks, imageMap: imageMap)
                    .blockSpacing(20)
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal)
            } else {
                // Collapsed: show summary/first lines
                VStack(alignment: .leading, spacing: 8) {
                    if let summary = entry.aiGeneratedSummary {
                        Text(summary)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    } else if let firstText = entry.blocks.first(where: { if case .text = $0.type { return true } else { return false } }) {
                        if case let .text(text) = firstText.type {
                            Text(text)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    } else {
                        Text("No entry yet. Start logging your food!")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            Spacer(minLength: 0)
            
            // Footer
            EntryFooterView(
                calorieSummary: "\(entry.totalCalories ?? 0) kcal",
                onAddImage: { onAddImage?() }
            )
            .padding(.bottom, 8)
        }
        .frame(height: isExpanded ? nil : height)
        .background(Color.white)
        .cornerRadius(cornerRadius)
        .shadow(color: showShadow ? Color.black.opacity(0.08) : .clear, radius: 8, x: 0, y: 4)
        .onTapGesture {
            withAnimation(.spring()) {
                isExpanded.toggle()
                onTap?()
            }
        }
        .animation(.spring(), value: isExpanded)
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
            BigEntryBlock(entry: entry)
                .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
} 
