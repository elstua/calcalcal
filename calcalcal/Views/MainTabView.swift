import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @Namespace private var editorNamespace
    @State private var presentedEntry: DiaryEntry? = nil
    @State private var presentedBlocks: [Block] = []
    @State private var shouldFocusEditor: Bool = false
    @State private var isOverlayVisible: Bool = false
    
    var body: some View {
        ZStack {
            TabView {
                DiaryListView(
                    sharedNamespace: editorNamespace,
                    presentedEntryId: presentedEntry?.id,
                    onRequestOpen: { entry in
                        // Capture entry for overlay and animate
                        presentedEntry = entry
                        presentedBlocks = entry.blocks
                        // Reset focus so we request it after animation begins
                        shouldFocusEditor = false
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                            isOverlayVisible = true
                        }
                        // Trigger keyboard a moment after the transition starts for smoother feel
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            shouldFocusEditor = true
                        }
                    }
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
            
            if let entry = presentedEntry, isOverlayVisible {
                EditorOverlay(
                    entry: entry,
                    blocks: $presentedBlocks,
                    shouldBecomeFirstResponder: $shouldFocusEditor,
                    namespace: editorNamespace,
                    onClose: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                            isOverlayVisible = false
                        }
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
                        // Release reference after the collapse finishes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            presentedEntry = nil
                        }
                    }
                )
                .transition(.identity) // rely purely on matchedGeometryEffect
                .zIndex(100)
            }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AppState())
    }
} 

