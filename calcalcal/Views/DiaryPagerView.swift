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
    var spacing: CGFloat = DSSpacing.md
    var trailingSpace: CGFloat = 0
    let content: (DiaryPagerItem, Bool) -> Content
    var onExtendedSwipe: (() -> Void)? = nil
    @Binding var extendedSwipeDragOffset: CGFloat
    
    @State private var currentIndex: Int = 0
    @GestureState private var dragOffset: CGFloat = 0
    @State private var shouldTriggerExtendedSwipe: Bool = false
    
    private let extendedSwipeThreshold: CGFloat = 150
    
    init(
        items: [DiaryPagerItem],
        selectedDate: Binding<Date>,
        calendar: Calendar,
        spacing: CGFloat = DSSpacing.md,
        trailingSpace: CGFloat = DSSpacing.xxxl,
        onExtendedSwipe: (() -> Void)? = nil,
        extendedSwipeDragOffset: Binding<CGFloat> = .constant(0),
        @ViewBuilder content: @escaping (DiaryPagerItem, Bool) -> Content
    ) {
        self.items = items
        self._selectedDate = selectedDate
        self.calendar = calendar
        self.spacing = spacing
        self.trailingSpace = trailingSpace
        self.onExtendedSwipe = onExtendedSwipe
        self._extendedSwipeDragOffset = extendedSwipeDragOffset
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
        .simultaneousGesture(
            // Only active when on first page (oldest day) - uses simultaneousGesture to not interfere with TabView paging
            isOnFirstPage ? extendedSwipeGesture : nil
        )
        .scaleEffect(isOnFirstPage && dragOffset > 50 ? 0.98 : 1.0)
        .opacity(isOnFirstPage && dragOffset > 50 ? 0.9 : 1.0)
        .animation(.easeOut(duration: 0.2), value: dragOffset)
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
        .onChange(of: shouldTriggerExtendedSwipe) { shouldTrigger in
            if shouldTrigger {
                onExtendedSwipe?()
                shouldTriggerExtendedSwipe = false
            }
        }
    }
    
    private var isOnFirstPage: Bool {
        guard !items.isEmpty else { return false }
        return currentIndex == 0
    }
    
    private var extendedSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .updating($dragOffset) { value, state, _ in
                // Only track horizontal drag when swiping right (from oldest day, going further back)
                // and ensure it's primarily horizontal (not vertical)
                let isHorizontal = abs(value.translation.width) > abs(value.translation.height) * 2
                if isHorizontal && value.translation.width > 0 {
                    state = value.translation.width
                    // Update the binding so parent can show preview card
                    DispatchQueue.main.async {
                        extendedSwipeDragOffset = value.translation.width
                    }
                }
            }
            .onEnded { value in
                // Reset drag offset
                DispatchQueue.main.async {
                    extendedSwipeDragOffset = 0
                }
                
                // Check if it's a strong rightward swipe beyond threshold
                let isHorizontal = abs(value.translation.width) > abs(value.translation.height) * 2
                if isHorizontal && value.translation.width > extendedSwipeThreshold {
                    shouldTriggerExtendedSwipe = true
                }
            }
    }
    
    private func syncIndexWithSelection() {
        guard let idx = items.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: selectedDate) }) else { return }
        if currentIndex != idx {
            withAnimation {
                currentIndex = idx
            }
        }
    }
}
