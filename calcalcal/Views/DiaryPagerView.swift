import SwiftUI

struct DiaryPagerItem: Identifiable, Equatable {
    let id: String
    let date: Date
    let entry: DiaryEntry
}

/// Snapping carousel implementation derived from pdgna44’s “Snapping Carousel in SwiftUI, iOS 16”.
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
        SnapCarousel(
            list: items,
            spacing: spacing,
            trailingSpace: trailingSpace,
            index: $currentIndex
        ) { item in
            content(item, calendar.isDate(item.date, inSameDayAs: selectedDate))
        }
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

private struct SnapCarousel<Item: Identifiable, Content: View>: View {
    let list: [Item]
    var spacing: CGFloat
    var trailingSpace: CGFloat
    @Binding var index: Int
    @ViewBuilder let content: (Item) -> Content
    
    @State private var dragOffset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    /// Flag to track when we're handling a gesture-initiated animation.
    /// When true, onChange(of: index) should NOT animate (we handle it ourselves).
    @State private var isHandlingGesture: Bool = false
    
    var body: some View {
        GeometryReader { proxy in
            let cardWidth = max(0, proxy.size.width - trailingSpace)
            let step = cardWidth + spacing
            let centerAdjustment = (proxy.size.width - cardWidth) / 1.5
            
            HStack(spacing: spacing) {
                ForEach(list) { item in
                    content(item)
                        .frame(width: cardWidth)
                }
            }
            .contentShape(Rectangle())
            .offset(x: scrollOffset + dragOffset + centerAdjustment)
            .highPriorityGesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let progress = -value.translation.width / step
                        let rounded = progress.rounded()
                        let newIndex = clamp(index + Int(rounded))
                        let finalTarget = targetOffset(for: newIndex, step: step)
                        
                        // Merge drag offset into scroll offset so animation starts from finger's release position
                        scrollOffset += dragOffset
                        dragOffset = 0
                        
                        // Start animation FIRST, before any state changes
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollOffset = finalTarget
                        }
                        
                        // Update index AFTER animation completes
                        // This prevents parent state changes from interrupting the animation
                        if newIndex != index {
                            isHandlingGesture = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                index = newIndex
                                isHandlingGesture = false
                            }
                        }
                    }
            )
            .onAppear {
                scrollOffset = targetOffset(for: index, step: step)
            }
            .onChange(of: index) { newValue in
                // Only animate if this is an external change (e.g., tapping day strip)
                // Skip if we're already handling a gesture-initiated animation
                guard !isHandlingGesture else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    scrollOffset = targetOffset(for: newValue, step: step)
                }
            }
        }
    }
    
    private func targetOffset(for index: Int, step: CGFloat) -> CGFloat {
        -CGFloat(index) * step
    }
    
    private func clamp(_ value: Int) -> Int {
        guard !list.isEmpty else { return 0 }
        return min(max(value, 0), list.count - 1)
    }
}


