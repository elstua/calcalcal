import SwiftUI
import UIKit

struct DayStripItemModel: Identifiable, Equatable {
    let id: String
    let date: Date
    let calories: Int?
    let hasEntry: Bool
    let isInStreak: Bool
}

struct DayStripView: View {
    let items: [DayStripItemModel]
    let selectedDate: Date
    let currentStreak: Int
    let onSelectDate: (Date) -> Void
    let onShowAllDays: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        HStack(spacing: 0) {
            DayStripStreakButton(action: onShowAllDays)
            
            ForEach(items) { item in
                DayStripItemView(
                    model: item,
                    isSelected: calendar.isDate(item.date, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(item.date),
                    onTap: { onSelectDate(item.date) }
                )
            }
        }
    }
}

private struct DayStripItemView: View {
    let model: DayStripItemModel
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void
    
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
    
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                VStack(spacing: 0){
                    Text(Self.dayFormatter.string(from: model.date))
                        .dsTypography(.body)
                        .foregroundColor(isSelected || isToday ? DSColors.primary : DSColors.textPrimary)
                    
                    Text(Self.weekdayFormatter.string(from: model.date).uppercased())
                        .dsTypography(.caption)
                        .foregroundColor(isSelected || isToday ? DSColors.primary : DSColors.textSecondary)
                }
                
                Text(calorieText)
                    .dsTypography(.compactNumber)
                    .foregroundColor(model.hasEntry ? (isSelected ? DSColors.primary : DSColors.textSecondary) : DSColors.textSecondary.opacity(0.6))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? DSColors.primary.opacity(0.12) : DSColors.backgroundTertiary.opacity(0))
            .cornerRadius(32)

        }
        .buttonStyle(.plain)
    }
    
    private var calorieText: String {
        if let calories = model.calories {
            return "\(calories)"
        }
        return model.hasEntry ? "—" : "×"
    }
}

private struct DayStripStreakButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DSColors.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white)
                    )
                
                Text("all days")
                    .dsTypography(.caption)
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            
        }
        .buttonStyle(.plain)
    }
}

