import Foundation

struct ParagraphInfo: Identifiable, Equatable {
    let id: UUID
    let range: NSRange
    var text: String
    var calories: Int?
    var blockType: BlockType = .textBlock
    
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // Check if this paragraph is at the end of text
    var isLastParagraph: Bool = false
    
    init(id: UUID = UUID(), range: NSRange, text: String, calories: Int? = nil, blockType: BlockType = .textBlock, isLastParagraph: Bool = false) {
        self.id = id
        self.range = range
        self.text = text
        self.calories = calories
        self.blockType = blockType
        self.isLastParagraph = isLastParagraph
    }
    
    static func == (lhs: ParagraphInfo, rhs: ParagraphInfo) -> Bool {
        lhs.id == rhs.id &&
        lhs.range == rhs.range &&
        lhs.text == rhs.text &&
        lhs.calories == rhs.calories &&
        lhs.blockType == rhs.blockType &&
        lhs.isLastParagraph == rhs.isLastParagraph
    }
}
