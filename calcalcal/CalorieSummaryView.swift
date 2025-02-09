//
//  CalorieSummaryView.swift
//  calcalcal
//
//  Created by Artem Savelev on 09/02/2025.
//


import SwiftUI

struct CalorieSummaryView: View {
    let total: Int
    
    var body: some View {
        Text("Total: \(total) kcal")
            .font(.headline)
            .padding()
    }
}
