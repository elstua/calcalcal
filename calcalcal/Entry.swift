//
//  Entry.swift
//  calcalcal
//
//  Created by Artem Savelev on 09/02/2025.
//
import Foundation

struct Entry: Identifiable {
    let id = UUID()
    var text: String
    var calories: Int?
}
