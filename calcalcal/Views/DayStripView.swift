import SwiftUI
import UIKit

struct DayStripItemModel: Identifiable, Equatable {
    let id: String
    let date: Date
    let calories: Int?
    let hasEntry: Bool
}

struct DayStripView: View {
    let items: [DayStripItemModel]
    let selectedDate: Date
    let onSelectDate: (Date) -> Void
    let onShowAllDays: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                DayStripItemView(
                    model: item,
                    isSelected: calendar.isDate(item.date, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(item.date),
                    onTap: { onSelectDate(item.date) }
                )
            }
            
            DayStripAllDaysButton(action: onShowAllDays)
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
                        .font(.title3.weight(.regular))
                        .foregroundColor(numberColor)
                    
                    Text(Self.weekdayFormatter.string(from: model.date).uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundColor(weekdayColor)
                }
                
                Text(calorieText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(calorieColor)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(32)

        }
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.12)
        }
        return Color(.secondarySystemBackground)
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color.accentColor
        }
        return Color(.tertiarySystemFill)
    }
    
    private var weekdayColor: Color {
        if isSelected {
            return Color.accentColor
        }
        if isToday {
            return Color.accentColor
        }
        return Color.secondary
    }
    
    private var numberColor: Color {
        if isSelected {
            return Color.accentColor
        }
        if isToday {
            return Color.accentColor
        }
        return Color.primary
    }
    
    private var calorieColor: Color {
        if model.hasEntry {
            return isSelected ? Color.accentColor : Color.secondary
        }
        return Color.secondary.opacity(0.6)
    }
    
    private var calorieText: String {
        if let calories = model.calories {
            return "\(calories)"
        }
        return model.hasEntry ? "—" : "×"
    }
}

private struct DayStripAllDaysButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: "calendar")
                    .font(.headline)
                Text("All days")
                    .font(.caption)
                    
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .cornerRadius(32)
        }
        .buttonStyle(.plain)
    }
}

