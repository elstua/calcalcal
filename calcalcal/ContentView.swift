import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DocumentViewModel()
    @State private var isTextFieldFocused = false
    
    var body: some View {
        VStack(spacing: 0) {
            // FlexibleTextEditor gets a fixed frame with clipping
            FlexibleTextEditor(
                text: Binding(
                    get: { viewModel.text },
                    set: { viewModel.processTextChange($0) }
                ),
                isFocused: $isTextFieldFocused,
                slotProviders: [
                    CalorieSlotProvider()
                ],
                onCaloriesCalculated: { total in
                    viewModel.updateTotalCalories(total)
                }
            )
            // Make the text editor take available space but not expand
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Apply clipping to ensure content doesn't overflow
            .clipShape(Rectangle())
            
            // Add a stronger visual separator
            Divider()
                .background(Color.gray.opacity(0.7))
                .padding(.vertical, 2)
            
            // Total calories display - now with a background color to better separate it
            HStack {
                Text("Total: \(viewModel.totalCalories) kcal")
                    .font(.headline)
                    .padding()
                Spacer()
            }
            .background(Color(UIColor.systemBackground))
            // Add shadow for visual separation
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: -1)
        }
    }
}

#Preview {
    ContentView()
}
