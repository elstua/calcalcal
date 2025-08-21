import SwiftUI

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


