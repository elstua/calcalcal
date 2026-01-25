import SwiftUI

/// A card component displaying streak statistics at the top of the all-days view
struct StreakStatsView: View {
    let streaksData: StreaksData?
    
    var body: some View {
        VStack(spacing: 12) {
            statRow(
                emoji: "🔥",
                label: "Current Streak",
                value: "\(streaksData?.currentStreak ?? 0) days"
            )
            
            Divider()
                .background(DSColors.textSecondary.opacity(0.2))
            
            statRow(
                emoji: "🏆",
                label: "Longest Streak",
                value: "\(streaksData?.longestStreak ?? 0) days"
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
    }
    
    @ViewBuilder
    private func statRow(emoji: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 28))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .dsTypography(.caption)
                    .foregroundColor(DSColors.textSecondary)
                
                Text(value)
                    .dsTypography(.body)
                    .foregroundColor(DSColors.textPrimary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview
struct StreakStatsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            StreakStatsView(streaksData: StreaksData(
                currentStreak: 12,
                longestStreak: 45,
                totalDaysWithEntries: 120,
                lastEntryDate: "2026-01-25",
                streakStartDate: "2026-01-14"
            ))
            
            StreakStatsView(streaksData: nil)
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
    }
}
