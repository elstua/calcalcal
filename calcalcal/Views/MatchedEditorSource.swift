import SwiftUI

// MARK: - Legacy Matched Editor Source (for iOS < 18 fallback)
struct MatchedEditorSource: ViewModifier {
    let id: UUID
    let isPresented: Bool
    let namespace: Namespace.ID?
    
    func body(content: Content) -> some View {
        if let ns = namespace {
            content
                .opacity(isPresented ? 0 : 1)
                .allowsHitTesting(!isPresented)
                .matchedGeometryEffect(id: id, in: ns)
        } else {
            content
        }
    }
}

extension View {
    func matchedEditorSource(id: UUID, isPresented: Bool, namespace: Namespace.ID?) -> some View {
        self.modifier(MatchedEditorSource(id: id, isPresented: isPresented, namespace: namespace))
    }
}

// MARK: - iOS 18+ Zoom Transition Source
/// Marks a view as the source for a zoom transition.
/// On iOS 18+, uses the native `matchedTransitionSource` API.
/// On earlier versions, this is a no-op (the presentation will use standard animation).
struct ZoomTransitionSourceModifier: ViewModifier {
    let id: UUID
    let namespace: Namespace.ID
    
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

extension View {
    /// Marks this view as the source for an iOS 18+ zoom transition.
    /// - Parameters:
    ///   - id: Unique identifier for the transition (typically the entry's UUID)
    ///   - namespace: The namespace shared between source and destination
    func zoomTransitionSource(id: UUID, namespace: Namespace.ID) -> some View {
        self.modifier(ZoomTransitionSourceModifier(id: id, namespace: namespace))
    }
}

// MARK: - iOS 18+ Zoom Transition Full Screen Cover
/// A view modifier that presents a fullScreenCover with iOS 18+ zoom transition.
/// On iOS 18+, the cover animates with a zoom effect from the matched source.
/// On earlier versions, the cover uses the standard slide-up animation.
struct ZoomTransitionFullScreenCoverModifier<Item: Identifiable, Destination: View>: ViewModifier {
    @Binding var item: Item?
    let namespace: Namespace.ID
    let destination: (Item) -> Destination
    
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.fullScreenCover(item: $item) { presentedItem in
                destination(presentedItem)
                    .navigationTransition(.zoom(sourceID: presentedItem.id, in: namespace))
            }
        } else {
            // Fallback for iOS < 18: standard fullScreenCover without zoom
            content.fullScreenCover(item: $item) { presentedItem in
                destination(presentedItem)
            }
        }
    }
}

extension View {
    /// Presents a fullScreenCover with iOS 18+ zoom transition.
    /// - Parameters:
    ///   - item: Binding to the optional item that triggers presentation
    ///   - namespace: The namespace shared with the source view's `zoomTransitionSource`
    ///   - content: The view builder for the presented content
    func zoomTransitionFullScreenCover<Item: Identifiable, Destination: View>(
        item: Binding<Item?>,
        namespace: Namespace.ID,
        @ViewBuilder content: @escaping (Item) -> Destination
    ) -> some View {
        self.modifier(ZoomTransitionFullScreenCoverModifier(
            item: item,
            namespace: namespace,
            destination: content
        ))
    }
    
    /// Applies the zoom transition to a specific view (not the whole screen).
    /// Use this when you want only part of the fullScreenCover to zoom.
    /// - Parameters:
    ///   - id: The ID matching the source view
    ///   - namespace: The shared namespace
    func applyZoomTransition(id: UUID, namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            return AnyView(self.navigationTransition(.zoom(sourceID: id, in: namespace)))
        } else {
            return AnyView(self)
        }
    }
}


