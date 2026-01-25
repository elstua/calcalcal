import SwiftUI
import UIKit

/// Fullscreen overlay for the all-days list view with swipe-to-dismiss support
struct AllDaysOverlay: View {
    let sharedNamespace: Namespace.ID
    let presentedEntryId: UUID?
    let isOverlayActive: Bool
    let streaksData: StreaksData?
    let onRequestOpen: (DiaryEntry) -> Void
    let onClose: () -> Void
    
    @GestureState private var dragOffset: CGSize = .zero
    @State private var hasDismissedForDrag: Bool = false
    
    var body: some View {
        // Transparent container
        Color.clear
            .overlay(
                // The actual content - this is what zooms
                cardContent
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
                    .padding(.bottom, 8)
            )
            .ignoresSafeArea(.keyboard)
    }
    
    private var cardContent: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Drag handle at the top
                dragHandle
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                
                DiaryListView(
                    sharedNamespace: sharedNamespace,
                    presentedEntryId: presentedEntryId,
                    onRequestOpen: onRequestOpen,
                    onDismiss: onClose,
                    isOverlayActive: isOverlayActive,
                    streaksData: streaksData
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(UIColor.systemGroupedBackground))
        )
        .overlay(alignment: .topTrailing) {
            Button(action: { onClose() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
            }
            .padding(12)
        }
        .offset(y: max(0, dragOffset.height))
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($dragOffset) { value, state, _ in
                    // Only allow downward drags
                    if value.translation.height > 0 {
                        state = value.translation
                    }
                }
                .onEnded { value in
                    // Check if drag was far enough or fast enough to dismiss
                    let shouldDismiss = value.translation.height > 120 || value.predictedEndTranslation.height > 180
                    if shouldDismiss {
                        onClose()
                    }
                }
        )
    }
    
    /// Drag handle view - a small pill that indicates the overlay can be dismissed
    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(Color.secondary.opacity(0.3))
            .frame(width: 36, height: 5)
    }
}
