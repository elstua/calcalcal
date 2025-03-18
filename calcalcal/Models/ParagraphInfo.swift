//
//  ParagraphInfo.swift
//  calcalcal
//
//  Created by Artem Savelev on 18/03/2025.
//


//
//  ParagraphInfo.swift
//  calcalcal
//
//  Created by Artem Savelev on 16/03/2025.
//

import Foundation

struct ParagraphInfo: Identifiable, Equatable {
    let id: UUID
    let range: NSRange
    var text: String
    var calories: Int?
    
    // Added isActive flag to track the currently active paragraph
    var isActive: Bool = false
    
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // Check if this paragraph is at the end of text
    var isLastParagraph: Bool = false
    
    init(id: UUID = UUID(), range: NSRange, text: String, calories: Int? = nil, isActive: Bool = false, isLastParagraph: Bool = false) {
        self.id = id
        self.range = range
        self.text = text
        self.calories = calories
        self.isActive = isActive
        self.isLastParagraph = isLastParagraph
    }
    
    static func == (lhs: ParagraphInfo, rhs: ParagraphInfo) -> Bool {
        lhs.id == rhs.id &&
        lhs.range == rhs.range &&
        lhs.text == rhs.text &&
        lhs.calories == rhs.calories &&
        lhs.isActive == rhs.isActive &&
        lhs.isLastParagraph == rhs.isLastParagraph
    }
}
