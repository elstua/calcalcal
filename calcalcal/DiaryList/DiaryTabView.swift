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
    
    // MARK: - Presentation State (iOS 18+ uses fullScreenCover with zoom transition)
    @State private var presentedEntry: DiaryEntry? = nil
    @State private var presentedBlocks: [Block] = []
    @State private var shouldFocusEditor: Bool = false
    
    // MARK: - Sheet State
    @State private var showAllDaysSheet: Bool = false
    @State private var pendingEntryFromSheet: DiaryEntry? = nil
    
    
    var body: some View {
        mainContent
            .fullScreenCover(item: $presentedEntry) { entry in
                // Just the card - no background
                EditorOverlay(
                    entry: entry,
                    blocks: $presentedBlocks,
                    shouldBecomeFirstResponder: $shouldFocusEditor,
                    namespace: editorNamespace,
                    onClose: {
                        handleOverlayClose(entry: entry)
                    }
                )
                .applyZoomTransition(id: entry.id, namespace: editorNamespace)
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
        .onReceive(NotificationCenter.default.publisher(for: .editorOverlayDidCommit)) { notification in
            handleEditorCommit(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .diaryEntryTotalsUpdated)) { notification in
            handleTotalsUpdated(notification)
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
                        onShowAllDays: { showAllDaysSheet = true }
                    )
                    .padding(.horizontal, 8)
                }
                

                dayPager
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .sheet(isPresented: $showAllDaysSheet, onDismiss: {
            Task {
                await viewModel.refreshVisibleEntries()
            }
            // If an entry was queued to open from the sheet, present it now
            if let entry = pendingEntryFromSheet {
                pendingEntryFromSheet = nil
                // Small delay to ensure sheet dismissal animation completes
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
//                    presentOverlay(for: entry)
//                }
            }
        }) {
            DiaryListView(
                sharedNamespace: nil,
                presentedEntryId: presentedEntry?.id,
                onRequestOpen: { entry in
                    // Queue the entry and dismiss sheet first - overlay will show after sheet closes
                    pendingEntryFromSheet = entry
                    showAllDaysSheet = false
                },
                isOverlayActive: false
            )
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
                DiaryPagerView(
                    items: viewModel.pagerItems,
                    selectedDate: $viewModel.selectedDay,
                    calendar: Calendar.current,
                    spacing: 12,
                    trailingSpace: 0
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
    
    // MARK: - Overlay Actions
    private func presentOverlay(for entry: DiaryEntry) {
        shouldFocusEditor = false
        presentedBlocks = entry.blocks
        presentedEntry = entry
    }
    
    private func handleOverlayClose(entry: DiaryEntry) {
        shouldFocusEditor = false

        // Update entry data
        viewModel.updateDayEntry(entryId: entry.id) { state in
            state.entry.blocks = presentedBlocks
            state.entry.lastModified = Date()
            state.isPlaceholder = viewModel.isPlaceholderContent(presentedBlocks)
        }
        NotificationCenter.default.post(
            name: .editorOverlayDidCommit,
            object: nil,
            userInfo: [
                "entryId": entry.id,
                "blocks": presentedBlocks
            ]
        )

        // Dismiss the fullScreenCover - iOS 18+ handles the zoom animation automatically
        presentedEntry = nil
    }
    
    // MARK: - Notification Handlers
    private func handleCanonicalIdResolved(_ notification: Notification) {
        guard let info = notification.userInfo,
              let localId = info["localId"] as? UUID,
              let serverId = info["serverId"] as? UUID else { return }
        if var current = presentedEntry, current.id == localId {
            current.id = serverId
            presentedEntry = current
        }
        viewModel.replaceEntryId(localId: localId, with: serverId)
    }
    
    private func handleEditorCommit(_ notification: Notification) {
        guard let info = notification.userInfo,
              let entryId = info["entryId"] as? UUID,
              let blocks = info["blocks"] as? [Block] else { return }
        viewModel.updateDayEntry(entryId: entryId) { state in
            state.entry.blocks = blocks
            state.entry.lastModified = Date()
            state.isPlaceholder = viewModel.isPlaceholderContent(blocks)
        }
    }
    
    private func handleTotalsUpdated(_ notification: Notification) {
        guard let info = notification.userInfo,
              let entryId = info["entryId"] as? UUID else { return }
        let value = info["totalCalories"]
        let total: Int?
        if value is NSNull {
            total = nil
        } else {
            total = value as? Int
        }
        viewModel.updateDayEntry(entryId: entryId) { state in
            state.entry.totalCalories = total
        }
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
