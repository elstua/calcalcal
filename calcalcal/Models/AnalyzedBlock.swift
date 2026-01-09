import Foundation

/// Minimal representation of an analyzed text block with nutrition data.
/// Built from server `blocks` for comparison and incremental analysis.
struct AnalyzedBlock {
    let id: String
    let position: Int
    let content: String

    let calories: Int?
    let protein: Double?
    let fat: Double?
    let carbs: Double?
    let fiber: Double?
    let sugar: Double?
    let sodium: Double?
    let weight: Double?
    let metricDescription: String?
    let confidence: Double?

    // Optional provider-specific payload; not used for client logic currently.
    let aiAnalysis: Any?
}


