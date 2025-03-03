import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DocumentViewModel()
    @State private var isTextFieldFocused = false
    
    var body: some View {
        VStack {
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
                },
                // Add action handler for the add button
                onAddButtonTapped: {
                    // Here you would handle what happens when the add button is tapped
                    // For example, prompt for image selection or manually enter food
                    print("Add button tapped from ContentView")
                    // Future implementation:
                    // - Open image picker
                    // - Call food recognition API
                    // - Insert food item with calories
                }
            )
            
            Divider()
            
            Text("Total: \(viewModel.totalCalories) kcal")
                .font(.headline)
                .padding()
        }
    }
}

#Preview {
    ContentView()
}
