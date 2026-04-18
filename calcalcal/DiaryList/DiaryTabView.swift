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
    
    // MARK: - Nutrition Popup State (shown inside the card)
    @State private var showCardNutritionPopup: Bool = false

    // MARK: - Media Picker State (inline overlay from each day card's '+' button)
    /// The entry whose day-card '+' button triggered the picker. `nil` = picker hidden.
    @State private var pickerTargetEntry: DiaryEntry? = nil
    /// Image selected from the main-screen picker, handed off to the editor on open.
    @State private var pendingPickedImage: UIImage? = nil

    // MARK: - Streak Sheet State
    @State private var showStreakSheet: Bool = false
    
    // MARK: - Streak Animation State
    @State private var previousStreak: Int = 0
    @State private var shouldAnimateStreak: Bool = false
    @State private var isAnimatingStreak: Bool = false
    @State private var streakAnimationTask: Task<Void, Never>? = nil
    
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
                    initialImage: pendingPickedImage,
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
            // IMPORTANT: Don't refresh if we just closed the editor
            // The onClose callback will update the view model with the latest data
            if !justClosedEditor {
                Task {
                    await viewModel.refreshVisibleEntries()
                }
            } else {
                DataFlowLogger.shared.backendRefreshSkipped(reason: "just closed editor (onAppear)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .diaryEntryCanonicalIdResolved)) { notification in
            handleCanonicalIdResolved(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .streaksDataUpdated)) { notification in
            handleStreaksUpdated(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .diaryEntryCaloriesUpdated)) { notification in
            handleEntryCaloriesUpdated(notification)
        }
        .overlay {
            if showStreakSheet {
                StreakPopupContainer(
                    streaksData: appState.streaksData,
                    isPresented: showStreakSheet,
                    onClose: { showStreakSheet = false }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if let target = pickerTargetEntry {
                UnifiedMediaPickerView(
                    onImageSelected: { image, _ in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            pickerTargetEntry = nil
                        }
                        pendingPickedImage = image
                        presentOverlay(for: target)
                    },
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            pickerTargetEntry = nil
                        }
                    },
                    geometryNamespace: editorNamespace
                )
                // Same as in EditorOverlay: the picker's background already extends
                // behind the safe area internally; letting the gallery panel respect
                // the top safe area keeps its header under the status bar.
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
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
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    // Header with Diary title and Streak button
                    HStack {
                        Text("Diary")
                            .font(.dsHeadline)
                            .foregroundColor(DSColors.primary)
                        
                        Spacer()
                        
                        // Streak button in header
                        StreakButton(
                            streak: appState.streaksData?.currentStreak ?? 0,
                            isAddingToStreak: shouldAnimateStreak,
                            previousStreak: previousStreak,
                            action: {
                                showStreakSheet = true
                            }
                        )
                        
//                        #if DEBUG
//                        // Debug button to test streak animation
//                        Button(action: {
//                            testStreakAnimation()
//                        }) {
//                            Image(systemName: "flame.fill")
//                                .font(.system(size: 14))
//                                .foregroundColor(.orange)
//                        }
//                        .padding(.leading, 8)
//                        #endif
                    }
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.top, DSSpacing.sm)

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
                    .padding(.horizontal, DSSpacing.sm)
                }
                

                dayPager
                    .padding(.top, DSSpacing.sm)
                    .padding(.bottom, DSSpacing.sm)
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
                        .font(.dsHeadline)
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
        
        // Create a content-aware ID that changes when blocks change
        // This forces SwiftUI to re-render immediately when content updates
        let contentHash = entry.blocks.toContentString().hashValue
        let viewId = "\(entry.stableViewId)_\(contentHash)"

        return VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                EntryCard(
                    entry: entry,
                    height: cardHeight,
                    cornerRadius: DSCornerRadius.xxl,
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

                // Same footer as editor, full size
                EditorFooterView(
                    blocks: entry.blocks,
                    remoteTotalCalories: entry.totalCalories,
                    scrollOffset: 0,
                    calorieGoal: appState.currentUser?.dailyCalorieGoal,
                    onAddImage: isActive ? {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            pickerTargetEntry = entry
                        }
                    } : {},
                    onCalorieTap: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showCardNutritionPopup = true
                        }
                    }
                )
                .padding(.bottom, DSSpacing.sm)
            }
            .overlay {
                if showCardNutritionPopup && isActive {
                    NutritionPopupContainer(
                        nutrition: entry.blocks.resolvedNutritionTotal(),
                        totalCalories: entry.blocks.resolvedCalorieTotal() ?? entry.totalCalories,
                        calorieGoal: appState.currentUser?.dailyCalorieGoal,
                        proteinGoal: appState.currentUser?.dailyProteinGoal,
                        fatGoal: appState.currentUser?.dailyFatGoal,
                        carbGoal: appState.currentUser?.dailyCarbGoal,
                        isPresented: showCardNutritionPopup,
                        onClose: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                showCardNutritionPopup = false
                            }
                        }
                    )
                    .transition(.opacity)
                    .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.xxl, style: .continuous))
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .id(viewId)  // Content-aware ID forces re-render when blocks change
            .zoomTransitionSource(id: entry.id, namespace: editorNamespace)
            .allowsHitTesting(isActive)
            .frame(height: cardHeight, alignment: .top)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private func placeholderCard<Content: View>(height: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        RoundedRectangle(cornerRadius: DSCornerRadius.full, style: .continuous)
            .fill(DSColors.surface)
            .frame(height: max(0, height))
            .overlay(content())
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.sm)
    }
    
    // MARK: - All Days Preview Card
    private func allDaysPreviewCard(availableHeight: CGFloat) -> some View {
        let cardHeight = max(0, availableHeight)
        
        return VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: DSCornerRadius.xxl, style: .continuous)
                .fill(DSColors.surface)
                .frame(height: cardHeight)
                .overlay {
                    VStack(spacing: DSSpacing.md) {
                        Image(systemName: "calendar")
                            .font(.dsLargeNumber)
                            .foregroundColor(DSColors.primary)
                        
                        Text("All Days")
                            .font(.dsHeadline)
                            .foregroundColor(DSColors.textPrimary)

                    }
                }
                .padding(.horizontal, DSSpacing.sm)
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
        
        // Store current streak before opening editor (for animation comparison later)
        previousStreak = appState.streaksData?.currentStreak ?? 0
        shouldAnimateStreak = false
        isAnimatingStreak = false
        
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
        // Clear any pending image so the next editor open doesn't re-attach it.
        pendingPickedImage = nil
        
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
        
        let newStreak = streaks.currentStreak
        let oldStreak = appState.streaksData?.currentStreak ?? 0
        
        // Check if streak increased after editor was closed
        if newStreak > previousStreak && newStreak > oldStreak && !isAnimatingStreak {
            // Only animate if app is in foreground
            guard UIApplication.shared.applicationState == .active else { return }
            
            // Cancel any existing animation task
            streakAnimationTask?.cancel()
            
            // Start animation with delay
            isAnimatingStreak = true
            shouldAnimateStreak = true
            
            streakAnimationTask = Task { @MainActor in
                // Wait 0.4s for main screen to fully appear
                try? await Task.sleep(nanoseconds: 400_000_000)
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                // Animation is now triggered via shouldAnimateStreak binding
                // Reset after animation completes (animation takes ~0.8s)
                try? await Task.sleep(nanoseconds: 800_000_000)
                
                guard !Task.isCancelled else { return }
                
                shouldAnimateStreak = false
                isAnimatingStreak = false
            }
        }
        
        appState.streaksData = streaks
    }

    private func handleEntryCaloriesUpdated(_ notification: Notification) {
        guard let info = notification.userInfo,
              let entryId = info["entryId"] as? UUID else { return }

        // Update the entry in the view model with the new calorie data
        if let totalCalories = info["totalCalories"] as? Int {
            viewModel.updateEntryCalories(entryId: entryId, totalCalories: totalCalories)
        }
    }
    
//    #if DEBUG
//    /// Test function to manually trigger streak animation
//    private func testStreakAnimation() {
//        // Set up fake previous streak (current - 1)
//        let currentStreak = appState.streaksData?.currentStreak ?? 3
//        previousStreak = max(0, currentStreak - 1)
//        
//        // Cancel any existing animation task
//        streakAnimationTask?.cancel()
//        
//        // Start animation
//        isAnimatingStreak = true
//        shouldAnimateStreak = true
//        
//        print("🔥 DEBUG: Testing streak animation from \(previousStreak) to \(currentStreak)")
//        
//        streakAnimationTask = Task { @MainActor in
//            // Wait 0.4s delay
//            try? await Task.sleep(nanoseconds: 400_000_000)
//            
//            guard !Task.isCancelled else { return }
//            
//            // Reset after animation completes
//            try? await Task.sleep(nanoseconds: 800_000_000)
//            
//            guard !Task.isCancelled else { return }
//            
//            shouldAnimateStreak = false
//            isAnimatingStreak = false
//            
//            print("🔥 DEBUG: Animation test complete")
//        }
//    }
//    #endif
}

// MARK: - Preview
struct DiaryTabView_Previews: PreviewProvider {
    static var previews: some View {
        DiaryTabView()
            .environmentObject(AppState())
    }
}
