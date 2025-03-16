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
                
                Button(action: {
                    // Save journal action
                    print("Save journal")
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.primary)
                }
                .padding(.horizontal)
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
                
                // Add button (shown only when text is empty)
                if text.isEmpty {
                    AddButton {
                        showingImagePicker = true
                    }
                    .padding([.top, .trailing], 16)
                }
            }
            
            // Footer with total calories
            HStack {
                Text("Total: \(totalCalories) kcal")
                    .font(.headline)
                    .padding()
                
                Spacer()
                
                // Info button
                Button(action: {
                    // Show info/help
                    print("Show info")
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.primary)
                }
                .padding(.horizontal)
            }
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
        // In a real app, you would:
        // 1. Upload the image or process it
        // 2. Get calorie information
        // 3. Insert it into the journal
        
        // For now, we'll just add placeholder text
        let existingText = text
        let imageMarker = "[Food Image: Calculating calories...]\n"
        
        // Append text at the beginning if document is empty, otherwise at the end
        if existingText.isEmpty {
            text = imageMarker
        } else if existingText.hasSuffix("\n") {
            text = existingText + imageMarker
        } else {
            text = existingText + "\n" + imageMarker
        }
        
        // Simulate a calculation and update
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
