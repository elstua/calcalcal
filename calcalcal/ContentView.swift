//
//  ContentView.swift
//  calcalcal
//
//  Created by Artem Savelev on 09/02/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = EntriesViewModel()
    @FocusState private var focusedField: UUID?
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
                        EntryRowView(
                            index: index,
                            text: Binding(
                                get: { entry.text },
                                set: { viewModel.updateEntry(at: index, text: $0) }
                            ),
                            calories: entry.calories,
                            focusId: entry.id,
                            onSubmit: {
                                viewModel.addNewEntry()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    focusedField = viewModel.entries.last?.id
                                }
                            },
                            onBackspace: {
                                if let previousId = viewModel.handleBackspace(at: index) {
                                    focusedField = previousId
                                }
                            }
                        )
                    }
                }
            }
            CalorieSummaryView(total: viewModel.totalCalories)
        }
    }
}

#Preview {
    ContentView()
}
