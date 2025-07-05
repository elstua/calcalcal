import SwiftUI
import Foundation
// Explicit imports for model visibility

// MARK: - DiaryListView
struct DiaryListView: View {
    @State private var entries: [DiaryEntry] = DiaryListView.generateMockEntries(count: 10)
    @State private var selectedEntry: DiaryEntry? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(entries.indices, id: \.self) { index in
                    let entry = entries[index]
                    if index == 0 {
                        // Today block (big)
                        BigEntryBlockWithSheet(entry: entry)
                            .padding(.horizontal)
                    } else {
                        SmallEntryBlock(entry: entry) {
                            selectedEntry = entry
                        }
                        .padding(.horizontal)
                        .sheet(item: $selectedEntry) { entry in
                            BigEntryBlock(entry: entry)
                                .padding()
                                .background(Color(.systemGroupedBackground))
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

// MARK: - Mock Data Generation
extension DiaryListView {
    static func generateMockEntries(count: Int) -> [DiaryEntry] {
        let calendar = Calendar.current
        let today = Date()
        return (0..<count).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let blocks = [
                Block(type: .text("Breakfast: \(Int.random(in: 1...3)) eggs, toast, juice"), calorieData: "\(Int.random(in: 200...400))"),
                Block(type: .text("Lunch: Chicken salad, apple"), calorieData: "\(Int.random(in: 300...500))"),
                Block(type: .text("Snack: Protein bar"), calorieData: "\(Int.random(in: 100...250))")
            ]
            let totalCalories = blocks.compactMap { Int($0.calorieData ?? "0") }.reduce(0, +)
            let summary = "Breakfast: eggs, toast, juice. Lunch: salad, apple. Snack: bar."
            return DiaryEntry(
                id: UUID(),
                date: date,
                blocks: blocks,
                totalCalories: totalCalories,
                lastModified: date,
                aiGeneratedSummary: summary
            )
        }
    }
}

// MARK: - Preview
struct DiaryListView_Previews: PreviewProvider {
    static var previews: some View {
        DiaryListView()
    }
} 
