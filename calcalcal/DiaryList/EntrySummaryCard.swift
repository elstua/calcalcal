import SwiftUI

/// Compact summary card for displaying diary entries in the "All Days" list.
/// Shows a day number circle, text preview, and calorie count.
struct EntrySummaryCard: View {
    let entry: DiaryEntry
    var onTap: (() -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(dayNumberString(entry.date))
                .font(.title3.bold())
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
                .background(Color.gray.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                SummaryTextView(entry: entry)
                Text("\(resolvedCaloriesText()) kcal")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .top)
    }
    
    private func resolvedCaloriesText() -> String {
        if let total = entry.totalCalories {
            return String(total)
        }
        return "…"
    }
    
    private func dayNumberString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

// MARK: - Summary Text View
private struct SummaryTextView: View {
    let entry: DiaryEntry
    
    var body: some View {
        let (contentBlocks, hasPlaceholderAtEnd) = getSummaryContent()
        
        if contentBlocks.isEmpty {
            Text("No entry yet. Start logging your food!")
                .font(.dsBody)
                .foregroundColor(DSColors.textPrimary)
                .lineLimit(2)
                .italic()
        } else if hasPlaceholderAtEnd && contentBlocks.count > 1 {
            // Show content + placeholder with different styling
            HStack(spacing: 4) {
                // Regular content (all blocks except last placeholder)
                Text(contentBlocks.dropLast().joined(separator: " "))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Placeholder at the end
                if let placeholderText = contentBlocks.last {
                    Text(placeholderText)
                        .font(.dsBody)
                        .foregroundColor(DSColors.textPlaceholder)
                        .lineLimit(2)
                }
            }
        } else if hasPlaceholderAtEnd {
            // Only placeholder
            Text(contentBlocks.joined(separator: " "))
                .font(.dsBody)
                .foregroundColor(DSColors.textPlaceholder)
                .lineLimit(2)
        } else {
            // Regular content only
            Text(contentBlocks.joined(separator: " "))
                .font(.dsBody)
                .foregroundColor(DSColors.textPlaceholder)
                .lineLimit(2)
        }
    }
    
    private func getSummaryContent() -> (blocks: [String], hasPlaceholderAtEnd: Bool) {
        // First check if we have an AI-generated summary
        if let summary = entry.aiGeneratedSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !summary.isEmpty {
            return ([summary], false)
        }

        // Filter to only text-bearing blocks
        let textBlocks = entry.blocks.compactMap { block -> (text: String, isPlaceholder: Bool)? in
            switch block.type {
            case .text(let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return nil }
                // Check for placeholder marker or legacy placeholder text
                let isPlaceholder = trimmed.isPlaceholderText || 
                    trimmed.lowercased() == "write what you ate today" ||
                    trimmed.lowercased() == "write what you ate this day"
                let cleanText = trimmed.strippingPlaceholderMarker
                return (cleanText, isPlaceholder)
            case .imageText(_, _, let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return nil }
                // Check for placeholder marker or legacy placeholder text
                let isPlaceholder = trimmed.isPlaceholderText || 
                    trimmed.lowercased() == "write what you ate today" ||
                    trimmed.lowercased() == "write what you ate this day"
                let cleanText = trimmed.strippingPlaceholderMarker
                return (cleanText, isPlaceholder)
            case .image, .spacer:
                return nil
            }
        }

        if textBlocks.isEmpty {
            return ([], false)
        }

        // Check if last block is a placeholder
        let hasPlaceholderAtEnd = textBlocks.last?.isPlaceholder ?? false
        
        // If we have content blocks and the last one is not a placeholder, add a placeholder
        var contentBlocks = textBlocks.map { $0.text }
        let shouldAddPlaceholder = !hasPlaceholderAtEnd && contentBlocks.count > 0
        
        if shouldAddPlaceholder {
            // Generate appropriate placeholder text based on date
            let isToday = Calendar.current.isDateInToday(entry.date)
            let placeholderText = isToday ? "write what you ate today" : "write what you ate this day"
            contentBlocks.append(placeholderText)
            return (contentBlocks, true)
        }
        
        return (contentBlocks, hasPlaceholderAtEnd)
    }
}
