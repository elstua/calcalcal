import SwiftUI

struct DayOverviewContextMenuView: View {
    let consumed: NutritionData
    let user: User?
    let width: CGFloat
    
    var body: some View {
        VStack(spacing: 16) {
            // Header: Calories Title (left) - Consumed/Goal (right)
            HStack(alignment: .top) {
                Text("Calories")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4) // Align with the number top
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(consumed.calories ?? 0))")
                        .font(.system(size: 34, weight: .bold, design: .rounded)) // H2-ish size
                        .foregroundColor(.primary)
                    
                    if let goal = user?.dailyCalorieGoal {
                        Text("/ \(goal) goal")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No goal set")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            // Macros Grid: 3 Columns
            HStack(spacing: 0) {
                MacroColumn(
                    title: "Carbs",
                    value: consumed.carbs ?? 0,
                    goal: user?.dailyCarbGoal
                )
                
                MacroColumn(
                    title: "Protein",
                    value: consumed.protein ?? 0,
                    goal: user?.dailyProteinGoal
                )
                
                MacroColumn(
                    title: "Fat",
                    value: consumed.fat ?? 0,
                    goal: user?.dailyFatGoal
                )
            }
        }
        .padding(20)
        .frame(width: width)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

struct MacroColumn: View {
    let title: String
    let value: Double
    let goal: Double?
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Text("\(Int(value))g")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let goal = goal {
                Text("/ \(Int(goal))g")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("-")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct DayOverviewContextMenuView_Previews: PreviewProvider {
    static var samples: NutritionData {
        NutritionData(calories: 1250, protein: 95, fat: 45, carbs: 120)
    }
    
    // Create a mock user for preview since we can't easily init User struct (props are lets)
    // Actually User is Codable, we can decode or just rely on nil user testing
    // or assume we can init if we had the struct available (it is available).
    // Wait, User init is 'from decoder'. We can't init easily without JSON.
    // Let's pass nil or create a dummy user JSON decoding helper if needed.
    // For now showing without user goals or assuming nil.
    
    static var previews: some View {
        DayOverviewContextMenuView(
            consumed: samples,
            user: nil,
            width: 300
        )
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
