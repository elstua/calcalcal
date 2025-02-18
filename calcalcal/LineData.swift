import SwiftUI

struct LineData: Identifiable, Equatable {
    let id: UUID
    let text: String
    let lineRect: CGRect
    let lineIndex: Int
    var metadata: [String: AnyHashable] // Using AnyHashable instead of Any
    
    static func == (lhs: LineData, rhs: LineData) -> Bool {
        return lhs.id == rhs.id &&
               lhs.text == rhs.text &&
               lhs.lineRect == rhs.lineRect &&
               lhs.lineIndex == rhs.lineIndex
        // Note: We're ignoring metadata in equality comparison
    }
}
