import SwiftUI

/// Extension to support creating bindings to optional values
/// This is needed for SwiftUI fullScreenCover with item: parameter
extension Binding {
    /// Creates a binding to an optional value, unwrapping it safely
    /// Returns nil if the source value is nil
    init?(_ source: Binding<Value?>) {
        guard let value = source.wrappedValue else { return nil }
        self.init(
            get: { source.wrappedValue ?? value },
            set: { source.wrappedValue = $0 }
        )
    }
}
