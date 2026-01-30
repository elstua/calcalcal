import SwiftUI
import UIKit

// MARK: - Day Entry State
/// Represents the state of a diary entry for a specific day
struct DayEntryState {
    var entry: DiaryEntry
    var isPlaceholder: Bool
}

// MARK: - Diary Tab View
/// The main diary tab view containing the day strip, pager, and editor overlay.
/// This view manages the diary entries for visible days and handles opening/editing entries.
struct DiaryTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = DiaryTabViewModel()
    @Namespace private var editorNamespace
    @Namespace private var allDaysNamespace
    
    // MARK: - Presentation State (iOS 18+ uses fullScreenCover with zoom transition)
    @State private var presentedEntry: DiaryEntry? = nil
    @State private var shouldFocusEditor: Bool = false
    @State private var justClosedEditor: Bool = false
    
    // MARK: - All Days View State
    @State private var showAllDaysView: Bool = false
    @State private var pendingEntryFromAllDays: DiaryEntry? = nil
    @State private var extendedSwipeDragOffset: CGFloat = 0
    @State private var showAllDaysPreviewCard: Bool = false
    
    // Constant ID for all-days view zoom transition
    private let allDaysViewId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    
    
    var body: some View {
        mainContent
            .fullScreenCover(item: $presentedEntry) { entry in
                // Create a direct binding wrapper
                EditorOverlay(
                    entry: Binding(
                        get: { presentedEntry ?? entry },
                        set: { presentedEntry = $0 }
                    ),
                    shouldBecomeFirstResponder: $shouldFocusEditor,
                    namespace: editorNamespace,
                    onClose: { finalEntry in
                        handleOverlayClose(with: finalEntry)
                    }
                )
                .applyZoomTransition(id: entry.id, namespace: editorNamespace)
            }
            .fullScreenCover(isPresented: $showAllDaysView, onDismiss: {
                // IMPORTANT: Only refresh if we're not in the middle of editing
                // This prevents overwriting recently saved data with stale backend data
                if presentedEntry == nil && !justClosedEditor {
                    Task {
                        // Add small delay to ensure cache writes and backend saves complete
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        await viewModel.refreshVisibleEntries()
                    }
                } else {
                    let reason = presentedEntry != nil ? "editor active" : "just closed editor"
                    DataFlowLogger.shared.backendRefreshSkipped(reason: reason)
                }
                
                // If an entry was queued to open from the all-days view, present it now
                if let entry = pendingEntryFromAllDays {
                    pendingEntryFromAllDays = nil
                    // Small delay to ensure fullScreenCover dismissal animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        presentOverlay(for: entry)
                    }
                }
            }) {
                DiaryListView(
                    sharedNamespace: allDaysNamespace,
                    presentedEntryId: presentedEntry?.id,
                    onRequestOpen: { entry in
                        // Queue the entry and dismiss fullScreenCover first
                        pendingEntryFromAllDays = entry
                        showAllDaysView = false
                    },
                    onDismiss: {
                        showAllDaysView = false
                    },
                    isOverlayActive: presentedEntry != nil,
                    streaksData: appState.streaksData
                )
                .applyZoomTransition(id: allDaysViewId, namespace: allDaysNamespace)
            }
        .onAppear {
            viewModel.ensurePlaceholdersForVisibleDays()
            Task {
                await viewModel.refreshVisibleEntries()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .diaryEntryCanonicalIdResolved)) { notification in
            handleCanonicalIdResolved(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .streaksDataUpdated)) { notification in
            handleStreaksUpdated(notification)
        }
    }
    
    // MARK: - Main Content
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            // Background that fills entire screen including safe area
            DSColors.background
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Diary")
                        .font(.dsHeadline)
                        .foregroundColor(DSColors.primary)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    DayStripView(
                        items: viewModel.dayStripItems(streaksData: appState.streaksData),
                        selectedDate: viewModel.selectedDay,
                        currentStreak: appState.streaksData?.currentStreak ?? 0,
                        onSelectDate: { viewModel.selectDay($0) },
                        onShowAllDays: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showAllDaysView = true
                            }
                        }
                    )
                    .padding(.horizontal, 8)
                }
                

                dayPager
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    
    // MARK: - Day Pager
    @ViewBuilder
    private var dayPager: some View {
        if viewModel.pagerItems.isEmpty {
            GeometryReader { proxy in
                placeholderCard(height: proxy.size.height) {
                    Text("loading...")
                        .font(.headline)
                        .foregroundColor(DSColors.textSecondary)
                }
            }
        } else {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    DiaryPagerView(
                        items: viewModel.pagerItems,
                        selectedDate: $viewModel.selectedDay,
                        calendar: Calendar.current,
                        spacing: 12,
                        trailingSpace: 0,
                        onExtendedSwipe: {
                            showAllDaysPreviewCard = false
                            showAllDaysView = true
                        },
                        extendedSwipeDragOffset: $extendedSwipeDragOffset
                    ) { item, isActive in
                        cardView(for: item.entry, isActive: isActive, availableHeight: proxy.size.height)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .overlay(alignment: .topTrailing) {
                        if viewModel.isLoadingRecentDays {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding()
                        }
                    }
                    .onChange(of: extendedSwipeDragOffset) { offset in
                        showAllDaysPreviewCard = offset > 0
                    }
                    
                    // Preview card that slides in during gesture
                    if showAllDaysPreviewCard && extendedSwipeDragOffset > 0 {
                        allDaysPreviewCard(availableHeight: proxy.size.height)
                            .offset(x: -proxy.size.width + extendedSwipeDragOffset + 8)
                            .opacity(min(extendedSwipeDragOffset / 150, 1.0))
                    }
                }
            }
        }
    }
    
    // MARK: - Card View
    private func cardView(for entry: DiaryEntry, isActive: Bool, availableHeight: CGFloat) -> some View {
        let cardHeight = max(0, availableHeight)

        return VStack(spacing: 0) {
            BigEntryBlock(
                entry: entry,
                height: cardHeight,
                cornerRadius: 24,
                showShadow: true,
                useExternalDecoration: false,
                onAddImage: nil,
                onTap: isActive ? {
                    presentOverlay(for: entry)
                } : nil,
                imageMap: [:],
                isEditable: false,
                shouldBecomeFirstResponder: .constant(false),
                forceExpanded: false
            )
            .padding(.horizontal, 8)
            .id(entry.id)
            .zoomTransitionSource(id: entry.id, namespace: editorNamespace)
            .allowsHitTesting(isActive)
            .frame(height: cardHeight, alignment: .top)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private func placeholderCard<Content: View>(height: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(DSColors.surface)
            .frame(height: max(0, height))
            .overlay(content())
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
    }
    
    // MARK: - All Days Preview Card
    private func allDaysPreviewCard(availableHeight: CGFloat) -> some View {
        let cardHeight = max(0, availableHeight)
        
        return VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DSColors.surface)
                .frame(height: cardHeight)
                .overlay {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar")
                            .font(.system(size: 48))
                            .foregroundColor(DSColors.primary)
                        
                        Text("All Days")
                            .font(.dsHeadline)
                            .foregroundColor(DSColors.textPrimary)
                        
                        if let streaks = appState.streaksData {
                            Text("🔥 \(streaks.currentStreak) day streak")
                                .font(.dsBody)
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .id("all-days-view")
                .zoomTransitionSource(id: allDaysViewId, namespace: allDaysNamespace)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Overlay Actions
    private func presentOverlay(for entry: DiaryEntry) {
        var entryWithStableIds = entry
        entryWithStableIds.blocks = entry.blocks.withStableIdsAndChangeTracking()
        presentedEntry = entryWithStableIds
        shouldFocusEditor = true
    }
    
    private func handleOverlayClose(with updatedEntry: DiaryEntry) {
        print("🟢 handleOverlayClose START - blocks=\(updatedEntry.blocks.count)")
        
        DataFlowLogger.shared.viewModelUpdating(
            entryId: updatedEntry.id, 
            blockCount: updatedEntry.blocks.count, 
            isPlaceholder: viewModel.isPlaceholderContent(updatedEntry.blocks)
        )
        
        // CRITICAL: Clear presentedEntry FIRST to prevent re-triggering fullScreenCover
        print("🟢 Setting presentedEntry = nil")
        presentedEntry = nil
        shouldFocusEditor = false
        
        // Update the source entry in the view model
        let isPlaceholder = viewModel.isPlaceholderContent(updatedEntry.blocks)
        viewModel.updateDayEntry(entryId: updatedEntry.id) { state in
            state.entry = updatedEntry
            state.isPlaceholder = isPlaceholder
        }
        DataFlowLogger.shared.viewModelUpdated(entryId: updatedEntry.id, isPlaceholder: isPlaceholder)
        
        print("🟢 handleOverlayClose END")
        
        // Mark that we just closed the editor to prevent immediate refresh
        justClosedEditor = true
        DataFlowLogger.shared.editorJustClosedFlagSet()
        
        // After a delay, allow refreshes again
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                justClosedEditor = false
                DataFlowLogger.shared.editorJustClosedFlagCleared()
            }
        }
    }
    
    // MARK: - Notification Handlers
    private func handleCanonicalIdResolved(_ notification: Notification) {
        guard let info = notification.userInfo,
              let localId = info["localId"] as? UUID,
              let serverId = info["serverId"] as? UUID else { return }
        
        // IMPORTANT: Do NOT update presentedEntry while the editor is open.
        // EditorOverlay already updates its own localEntry.id internally.
        // Updating presentedEntry here would cause SwiftUI's fullScreenCover(item:)
        // to see a "different" item (because DiaryEntry identity is based on id),
        // which triggers dismiss + re-present, losing user content.
        // 
        // We only update the view model's backing data, which will sync when
        // the overlay closes via handleOverlayClose().
        viewModel.replaceEntryId(localId: localId, with: serverId)
    }
    
    private func handleStreaksUpdated(_ notification: Notification) {
        guard let info = notification.userInfo,
              let streaks = info["streaks"] as? StreaksData else { return }
        appState.streaksData = streaks
    }
}

// MARK: - Preview
struct DiaryTabView_Previews: PreviewProvider {
    static var previews: some View {
        DiaryTabView()
            .environmentObject(AppState())
    }
}
