//
//  EntriesViewModel.swift
//  calcalcal
//
//  Created by Artem Savelev on 09/02/2025.
//


import SwiftUI

class EntriesViewModel: ObservableObject {
    @Published var entries: [Entry] = [Entry(text: "", calories: nil)]
    
    var totalCalories: Int {
        entries.compactMap { $0.calories }.reduce(0, +)
    }
    
    func addNewEntry() {
        entries.append(Entry(text: "", calories: nil))
    }
    
    func handleBackspace(at index: Int) -> UUID? {
        guard index > 0, entries[index].text.isEmpty else { return nil }
        entries.remove(at: index)
        return entries[index - 1].id
    }
    
    func mergeWithPreviousEntry(at index: Int) -> UUID? {
        guard index > 0 else { return nil }
        entries[index - 1].text += entries[index].text
        entries.remove(at: index)
        return entries[index - 1].id
    }
    
    func updateEntry(at index: Int, text: String) {
        entries[index].text = text
        if !text.isEmpty {
            entries[index].calories = Int.random(in: 100...500)
        } else {
            entries[index].calories = nil
        }
    }
}
