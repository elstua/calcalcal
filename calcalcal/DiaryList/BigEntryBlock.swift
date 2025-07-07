import SwiftUI
import Foundation
import UIKit


// MARK: - DiaryEntry Model (for preview/demo)

struct BigEntryBlock: View {
    let entry: DiaryEntry
    var height: CGFloat = 550
    var cornerRadius: CGFloat = 24
    var showShadow: Bool = true
    var onAddImage: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil
    // For now, imageMap is empty; can be extended for real images
    var imageMap: [UUID: UIImage] = [:]
    var isEditable: Bool = false
    @Binding var shouldBecomeFirstResponder: Bool
    
    @State private var isExpanded: Bool = false
    @State private var blocks: [Block]
    
    init(entry: DiaryEntry,
         height: CGFloat = 550,
         cornerRadius: CGFloat = 24,
         showShadow: Bool = true,
         onAddImage: (() -> Void)? = nil,
         onTap: (() -> Void)? = nil,
         imageMap: [UUID: UIImage] = [:],
         isEditable: Bool = false,
         shouldBecomeFirstResponder: Binding<Bool> = .constant(false)) {
        self.entry = entry
        self.height = height
        self.cornerRadius = cornerRadius
        self.showShadow = showShadow
        self.onAddImage = onAddImage
        self.onTap = onTap
        self.imageMap = imageMap
        self.isEditable = isEditable
        self._shouldBecomeFirstResponder = shouldBecomeFirstResponder
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
            
            // Always show the full editor
            UnifiedTextEditor(blocks: $blocks, imageMap: imageMap, isEditable: isEditable, shouldBecomeFirstResponder: $shouldBecomeFirstResponder)
                .blockSpacing(20)
                .frame(maxHeight: .infinity)
                .padding(.horizontal)
            
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

struct BigEntryBlockWithSheet: View {
    @State private var showSheet = false
    @State private var blocks: [Block]
    let entry: DiaryEntry
    var height: CGFloat = 550
    var cornerRadius: CGFloat = 24
    var showShadow: Bool = true
    var imageMap: [UUID: UIImage] = [:]
    var isEditable: Bool = false
    
    init(entry: DiaryEntry,
         height: CGFloat = 550,
         cornerRadius: CGFloat = 24,
         showShadow: Bool = true,
         imageMap: [UUID: UIImage] = [:],
         isEditable: Bool = false) {
        self.entry = entry
        self.height = height
        self.cornerRadius = cornerRadius
        self.showShadow = showShadow
        self.imageMap = imageMap
        self.isEditable = isEditable
        _blocks = State(initialValue: entry.blocks)
    }
    
    var body: some View {
        BigEntryBlock(
            entry: DiaryEntry(
                id: entry.id,
                date: entry.date,
                blocks: blocks,
                totalCalories: entry.totalCalories,
                lastModified: entry.lastModified,
                aiGeneratedSummary: entry.aiGeneratedSummary
            ),
            height: height,
            cornerRadius: cornerRadius,
            showShadow: showShadow,
            onAddImage: {},
            onTap: { showSheet = true },
            imageMap: imageMap,
            isEditable: isEditable
        )
        .fullScreenCover(isPresented: $showSheet) {
            NavigationView {
                BigEntryBlock(
                    entry: DiaryEntry(
                        id: entry.id,
                        date: entry.date,
                        blocks: blocks,
                        totalCalories: entry.totalCalories,
                        lastModified: entry.lastModified,
                        aiGeneratedSummary: entry.aiGeneratedSummary
                    ),
                    height: .infinity,
                    cornerRadius: 0,
                    showShadow: false,
                    onAddImage: {},
                    onTap: { showSheet = false },
                    imageMap: imageMap,
                    isEditable: isEditable
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showSheet = false }
                    }
                }
            }
        }
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
            BigEntryBlock(entry: entry, isEditable: false)
                .padding()
            BigEntryBlock(entry: entry, isEditable: true)
                .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct BigEntryBlockWithSheet_Previews: PreviewProvider {
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
            BigEntryBlockWithSheet(entry: entry)
                .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
} 
