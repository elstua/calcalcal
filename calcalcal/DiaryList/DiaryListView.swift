import SwiftUI
import Foundation
// Explicit imports for model visibility

// MARK: - DiaryListView
struct DiaryListView: View {
    @State private var entries: [DiaryEntry] = DiaryListView.generateMockEntries(count: 10)
    @State private var selectedEntry: DiaryEntry? = nil
    @State private var showPopup: Bool = false
    
    var body: some View {
        ZStack {
            ScrollView {
                let enumeratedEntries = Array(entries.enumerated())
                VStack(spacing: 20) {
                    ForEach(enumeratedEntries, id: \.element.id) { (index, entry) in
                        entryBlockView(index: index, entry: entry)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            
            if showPopup, let entry = selectedEntry {
                DiaryEntryPopupView(entry: entry, isPresented: $showPopup)
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
            }
        }
    }

    @ViewBuilder
    private func entryBlockView(index: Int, entry: DiaryEntry) -> some View {
        if index == 0 {
            BigEntryBlock(
                entry: entry,
                onTap: {
                    showPopup = true
                    selectedEntry = entry
                }, isEditable: false
            )
            .padding(.horizontal)
        } else {
            SmallEntryBlock(
                entry: entry,
                onTap: {
                    showPopup = true
                    selectedEntry = entry
                },
                isEditable: false
            )
            .padding(.horizontal)
        }
    }
}

// MARK: - Fullscreen Popup View
struct DiaryEntryPopupView: View {
    @State var entry: DiaryEntry
    @Binding var isPresented: Bool
    @GestureState private var dragOffset = CGSize.zero
    @State private var shouldFocusEditor = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            BigEntryBlock(entry: entry, isEditable: true, shouldBecomeFirstResponder: $shouldFocusEditor, forceExpanded: true)
                .padding()
                .cornerRadius(24)
                .shadow(radius: 10)
            Spacer()
        }
        .background(Color.black.opacity(0.2).ignoresSafeArea())
        .offset(y: dragOffset.height > 0 ? dragOffset.height : 0)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    if value.translation.height > 120 {
                        isPresented = false
                    }
                }
        )
        .animation(.spring(), value: dragOffset)
        .onAppear {
            shouldFocusEditor = true
        }
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
