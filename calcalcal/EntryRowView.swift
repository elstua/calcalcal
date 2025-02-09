//
//  EntryRowView.swift
//  calcalcal
//
//  Created by Artem Savelev on 09/02/2025.
//

import SwiftUI

struct EntryRowView: View {
    let index: Int
    @Binding var text: String
    let calories: Int?
    let focusId: UUID
    @FocusState private var isFocused: Bool
    let onSubmit: () -> Void
    let onBackspace: () -> Void
    
    var body: some View {
        HStack {
            TextField("Enter food...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isFocused)
                .onSubmit(onSubmit)
                .onChange(of: text) { newValue in
                    if newValue.isEmpty {
                        onBackspace()
                    }
                }
            
            if let calories = calories {
                Text("\(calories) kcal")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }
}
