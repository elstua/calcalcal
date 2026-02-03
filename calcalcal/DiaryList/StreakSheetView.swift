import SwiftUI
import UIKit

/// Sheet view displaying streak statistics
/// Shows current streak and longest streak
struct StreakSheetView: View {
    let streaksData: StreaksData?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                
                // Current Streak Section
                VStack(spacing: 8) {
                    
                    Text("\(streaksData?.currentStreak ?? 0)")
                        .dsTypography(.display)
                        .foregroundColor(DSColors.secondary)
                    
                    
                    Text("Days you've been consistent")
                        .dsTypography(.body)
                        .foregroundColor(DSColors.textSecondary)
                    
                }
                .padding(.horizontal, 24)
                
                
                 Divider()
                    .padding(.horizontal, 24)
                
                // Longest Streak Section
                HStack(spacing: 12) {
                    Text("Best Streak")
                        .dsTypography(.body)
                        .foregroundColor(DSColors.textSecondary)
                    Spacer()
                    HStack(spacing: 8) {
                        Text("\(streaksData?.longestStreak ?? 0)")
                            .dsTypography(.title2)
                            .foregroundColor(DSColors.textSecondary)

                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 40)
            .navigationTitle("Streaks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .dsTypography(.bodyEmphasized)
                    .foregroundColor(DSColors.primary)
                }
            }
        }
    }
    
}

// MARK: - Preview
struct StreakSheetView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with data
            StreakSheetView(
                streaksData: StreaksData(
                    currentStreak: 16,
                    longestStreak: 23,
                    totalDaysWithEntries: 45,
                    lastEntryDate: "2026-02-01",
                    streakStartDate: "2026-01-16"
                )
            )
            .previewDisplayName("With Data")
            
            // Preview with zero streak
            StreakSheetView(
                streaksData: StreaksData(
                    currentStreak: 0,
                    longestStreak: 5,
                    totalDaysWithEntries: 5,
                    lastEntryDate: nil,
                    streakStartDate: nil
                )
            )
            .previewDisplayName("Zero Streak")
            
            // Preview with no data
            StreakSheetView(streaksData: nil)
                .previewDisplayName("No Data")
        }
    }
}


