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
