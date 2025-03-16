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
    
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init(id: UUID = UUID(), range: NSRange, text: String, calories: Int? = nil) {
        self.id = id
        self.range = range
        self.text = text
        self.calories = calories
    }
    
    static func == (lhs: ParagraphInfo, rhs: ParagraphInfo) -> Bool {
        lhs.id == rhs.id &&
        lhs.range == rhs.range &&
        lhs.text == rhs.text &&
        lhs.calories == rhs.calories
    }
}