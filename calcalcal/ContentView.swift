import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = DocumentViewModel()
    
    var body: some View {
        VStack {
            FlexibleTextEditor(
                text: Binding(
                    get: { viewModel.text },
                    set: { viewModel.processTextChange($0) }
                ),
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
