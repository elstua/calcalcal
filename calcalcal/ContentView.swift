import SwiftUI

struct ContentView: View {
    @State private var text = ""
    @State private var totalCalories = 0
    @State private var isEditing = false
    @State private var showingImagePicker = false
    
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
                    showingImagePicker = true
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
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(isPresented: $showingImagePicker) { image in
                handleSelectedImage(image)
            }
        }
    }
    
    // Handle selected image
    private func handleSelectedImage(_ image: UIImage) {
        let imageMarker = "[Food Image: Calculating calories...]\n"
        
        // Append text at the beginning if document is empty, otherwise at the end
        if text.isEmpty {
            text = imageMarker
        } else if text.hasSuffix("\n") {
            text = text + imageMarker
        } else {
            text = text + "\n" + imageMarker
        }
        
        // Simulate a calculation
        simulateImageCalculation(imageMarker: imageMarker)
    }
    
    // Simulate image calorie calculation
    private func simulateImageCalculation(imageMarker: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Replace placeholder with calculated info
            let calculatedCalories = Int.random(in: 200...800)
            let imageInfoText = "[Food Image: \(calculatedCalories) kcal]\n"
            
            if let range = text.range(of: imageMarker) {
                text = text.replacingCharacters(in: range, with: imageInfoText)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
