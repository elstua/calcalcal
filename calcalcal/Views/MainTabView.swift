import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @Namespace private var editorNamespace
    @State private var presentedEntry: DiaryEntry? = nil
    @State private var presentedBlocks: [Block] = []
    @State private var shouldFocusEditor: Bool = false
    @State private var isOverlayVisible: Bool = false
    @State private var shouldHideSourceCard: Bool = false
    
    private let overlayAnimation = Animation.easeInOut(duration: 0.35)
    private let overlayAnimationDuration: Double = 0.35
    
    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                DiaryListView(
                    sharedNamespace: editorNamespace,
                    presentedEntryId: presentedEntry?.id,
                    onRequestOpen: { entry in
                        // Prepare focus and blocks, then present within a single animated transaction
                        shouldFocusEditor = false
                        shouldHideSourceCard = true
                        print("🐛 DEBUG: Opening entry \(entry.id.uuidString) with blocks: \(entry.blocks.map { $0.type })")
                        presentedBlocks = entry.blocks
                        withAnimation(overlayAnimation) {
                            presentedEntry = entry
                            isOverlayVisible = true
                        }
                        // Trigger keyboard a moment after the transition starts for smoother feel
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            shouldFocusEditor = true
                        }
                    },
                    isOverlayActive: shouldHideSourceCard
                )
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("Diary")
                }
                
                ProfileView()
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Profile")
                    }
            }
            
            overlayLayer
        }
        .onReceive(NotificationCenter.default.publisher(for: .diaryEntryCanonicalIdResolved)) { notification in
            guard let info = notification.userInfo,
                  let localId = info["localId"] as? UUID,
                  let serverId = info["serverId"] as? UUID else { return }
            if var current = presentedEntry, current.id == localId {
                current.id = serverId
                presentedEntry = current
            }
        }
    }
}

private extension MainTabView {
    @ViewBuilder
    var overlayLayer: some View {
        if let entry = presentedEntry, isOverlayVisible {
            EditorOverlay(
                entry: entry,
                blocks: $presentedBlocks,
                shouldBecomeFirstResponder: $shouldFocusEditor,
                namespace: editorNamespace,
                onClose: {
                    shouldHideSourceCard = false
                    // Clear focus quickly to avoid keyboard flashing on next open
                    DispatchQueue.main.async {
                        shouldFocusEditor = false
                    }
                    // Write back changes to the list via notification
                    NotificationCenter.default.post(
                        name: .editorOverlayDidCommit,
                        object: nil,
                        userInfo: [
                            "entryId": entry.id,
                            "blocks": presentedBlocks
                        ]
                    )
                    
                    let closingId = entry.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + overlayAnimationDuration) {
                        if presentedEntry?.id == closingId {
                            withAnimation(overlayAnimation) {
                                isOverlayVisible = false
                            }
                            presentedEntry = nil
                        }
                    }
                }
            )
            .transition(.identity) // rely purely on matchedGeometryEffect
            .zIndex(100)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AppState())
    }
}

