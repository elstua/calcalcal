import SwiftUI
import UIKit

struct ContentView: View {
    @State private var text = ""
    @State private var totalCalories = 0
    @State private var isEditing = false
    @State private var insertTrigger = 0 // State for triggering insertion
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("CalCalCal")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
            
            // Main unified text editor
            ZStack(alignment: .topTrailing) {
                CalorieTextEditor(
                    text: $text,
                    totalCalories: $totalCalories,
                    isEditing: $isEditing,
                    insertTrigger: $insertTrigger,
                    calculateCalories: { text, completion in
                        // Use our service for calorie calculation
                        CalorieCalculationService.shared.calculateCaloriesFor(
                            text: text,
                            completion: completion
                        )
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemBackground))
                .overlay(
                    // Placeholder overlay when text is empty
                    Group {
                        if text.isEmpty && !isEditing {
                            Text("Start to write what you eat...")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                )
            }
            
            // Footer with total calories and add button
            HStack {
                // Add button
                Button(action: {
                    // Increment the trigger to insert the block
                    insertTrigger += 1
                    
                    // Focus on the text editor (optional, might already be focused)
                    // isEditing = true // Consider if this is needed or handled by tap
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                }
                .padding(.leading)
                
                Spacer()
                
                // Total calories
                Text("Total: \(totalCalories) kcal")
                    .font(.headline)
                    .padding(.trailing)
            }
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: -1)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
