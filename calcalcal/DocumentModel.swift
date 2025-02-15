//
//  Entry 2.swift
//  calcalcal
//
//  Created by Artem Savelev on 15/02/2025.
//


import Foundation

struct Entry: Identifiable {
    let id: UUID
    var text: String
    var range: NSRange?
    var calories: Int?
    
    init(id: UUID = UUID(), text: String, range: NSRange? = nil, calories: Int? = nil) {
        self.id = id
        self.text = text
        self.range = range
        self.calories = calories
    }
}

class DocumentViewModel: ObservableObject {
    @Published var text: String = ""
    @Published private(set) var entries: [Entry] = []
    
    var totalCalories: Int {
        entries.compactMap { $0.calories }.reduce(0, +)
    }
    
    func processTextChange(_ newText: String) {
        self.text = newText
        updateEntries()
    }
    
    private func updateEntries() {
        // Split text into paragraphs
        let paragraphs = text.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        
        // Create or update entries
        var newEntries: [Entry] = []
        var currentLocation = 0
        
        for paragraph in paragraphs {
            let range = NSRange(location: currentLocation, length: paragraph.count)
            
            // Try to find existing entry with similar text
            if let existingEntryIndex = entries.firstIndex(where: { $0.text == paragraph }) {
                var updatedEntry = entries[existingEntryIndex]
                updatedEntry.range = range
                newEntries.append(updatedEntry)
            } else {
                // Create new entry
                let calories = !paragraph.isEmpty ? Int.random(in: 100...500) : nil
                let entry = Entry(text: paragraph, range: range, calories: calories)
                newEntries.append(entry)
            }
            
            currentLocation += paragraph.count + 1 // +1 for newline
        }
        
        entries = newEntries
    }
}
