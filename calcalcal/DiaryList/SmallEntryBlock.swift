import SwiftUI
import Foundation



struct SmallEntryBlock: View {
    let entry: DiaryEntry
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Day number
                Text(dayNumberString(entry.date))
                    .font(.title.bold())
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    // Summary or empty state
                    if let summary = entry.aiGeneratedSummary, !summary.isEmpty {
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
                    // Calorie summary
                    Text("\(entry.totalCalories ?? 0) kcal")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .padding(.top, 2)
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func dayNumberString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

// Move preview and DemoWrapper here so demo types are in scope
struct SmallEntryBlock_Previews: PreviewProvider {
    struct DemoWrapper: View {
        @State private var showSheet = false
        let entry = DiaryEntry(
            id: UUID(),
            date: Date().addingTimeInterval(-86400 * 2),
            blocks: [
                Block(type: .text("Lunch: Chicken salad, 1 apple"), calorieData: "410")
            ],
            totalCalories: 410,
            lastModified: Date(),
            aiGeneratedSummary: "Lunch: salad, apple."
        )
        var body: some View {
            SmallEntryBlock(entry: entry) {
                showSheet = true
            }
            .sheet(isPresented: $showSheet) {
                BigEntryBlock(entry: entry)
                    .padding()
                    .background(Color(.systemGroupedBackground))
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
    static var previews: some View {
        DemoWrapper()
    }
}
