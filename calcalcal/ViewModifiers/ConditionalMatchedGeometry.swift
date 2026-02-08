import SwiftUI

/// A ViewModifier that conditionally applies matchedGeometryEffect based on an enabled flag
/// This is useful for animations that should only apply in certain states (e.g., during transitions)
struct ConditionalMatchedGeometry<ID: Hashable>: ViewModifier {
    let enabled: Bool
    let id: ID
    let namespace: Namespace.ID
    let isSource: Bool
    let anchor: UnitPoint

    init(
        enabled: Bool,
        id: ID,
        namespace: Namespace.ID,
        isSource: Bool = true,
        anchor: UnitPoint = .top  // Use .top anchor by default for proper animation alignment
    ) {
        self.enabled = enabled
        self.id = id
        self.namespace = namespace
        self.isSource = isSource
        self.anchor = anchor
    }

    func body(content: Content) -> some View {
        if enabled {
            content.matchedGeometryEffect(id: id, in: namespace, anchor: anchor, isSource: isSource)
        } else {
            content
        }
    }
}
