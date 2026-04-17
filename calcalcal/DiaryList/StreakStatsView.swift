import SwiftUI

/// A card component displaying streak statistics at the top of the all-days view
struct StreakStatsView: View {
    let streaksData: StreaksData?
    
    var body: some View {
        VStack(spacing: DSSpacing.smd) {
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
        .padding(DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.lg, style: .continuous)
                .fill(DSColors.surface)
                .shadow(color: DSColors.shadowLight, radius: 4, x: 0, y: 2)
        )
    }
    
    @ViewBuilder
    private func statRow(emoji: String, label: String, value: String) -> some View {
        HStack(spacing: DSSpacing.smd) {
            Text(emoji)
                .font(.dsTitle1)
            
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
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
        VStack(spacing: DSSpacing.mlg) {
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
        .background(DSColors.background)
    }
}
