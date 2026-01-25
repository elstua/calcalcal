import SwiftUI

struct DiaryPagerItem: Identifiable, Equatable {
    let id: String
    let date: Date
    let entry: DiaryEntry
}

/// Paging carousel for displaying diary entries by day.
struct DiaryPagerView<Content: View>: View {
    let items: [DiaryPagerItem]
    @Binding var selectedDate: Date
    let calendar: Calendar
    var spacing: CGFloat = 16
    var trailingSpace: CGFloat = 0
    let content: (DiaryPagerItem, Bool) -> Content
    
    @State private var currentIndex: Int = 0
    
    init(
        items: [DiaryPagerItem],
        selectedDate: Binding<Date>,
        calendar: Calendar,
        spacing: CGFloat = 16,
        trailingSpace: CGFloat = 48,
        @ViewBuilder content: @escaping (DiaryPagerItem, Bool) -> Content
    ) {
        self.items = items
        self._selectedDate = selectedDate
        self.calendar = calendar
        self.spacing = spacing
        self.trailingSpace = trailingSpace
        self.content = content
    }
    
    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                content(item, calendar.isDate(item.date, inSameDayAs: selectedDate))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onAppear {
            syncIndexWithSelection()
        }
        .onChange(of: items) { _ in
            syncIndexWithSelection()
        }
        .onChange(of: selectedDate) { _ in
            syncIndexWithSelection()
        }
        .onChange(of: currentIndex) { newValue in
            guard items.indices.contains(newValue) else { return }
            let newDate = items[newValue].date
            if !calendar.isDate(newDate, inSameDayAs: selectedDate) {
                selectedDate = newDate
            }
        }
    }
    
    private func syncIndexWithSelection() {
        guard let idx = items.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: selectedDate) }) else { return }
        if currentIndex != idx {
            currentIndex = idx
        }
    }
}
