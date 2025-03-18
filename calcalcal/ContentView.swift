import SwiftUI

struct ContentView: View {
    @State private var text = ""
    @State private var totalCalories = 0
    @State private var isEditing = false
    @State private var showingImagePicker = false
    @State private var activeParagraphIndex: Int = 0
    
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
                },
                onParagraphAction: { paragraphIndex in
                    // Store the active paragraph index and show image picker
                    activeParagraphIndex = paragraphIndex
                    showingImagePicker = true
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemBackground))
            .overlay(
                // Placeholder overlay when text is empty and not editing
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
        // Get the current text
        let currentText = text
        
        // Get the active paragraph from our stored index
        if activeParagraphIndex < 0 || currentText.isEmpty {
            // If no active paragraph or empty text, just append at the end
            insertImageAtEnd(image)
            return
        }
        
        // In a real app, you would:
        // 1. Upload the image or process it
        // 2. Get calorie information
        // 3. Insert it at the specified paragraph
        
        // For demonstration, we'll insert at the active paragraph
        let imageMarker = "[Food Image: Calculating calories...]\n"
        
        // Split the text into paragraphs
        let nsText = currentText as NSString
        var paragraphRanges: [NSRange] = []
        
        let fullRange = NSRange(location: 0, length: nsText.length)
        nsText.enumerateSubstrings(in: fullRange, options: .byParagraphs) { (substring, substringRange, _, _) in
            if substring != nil {
                paragraphRanges.append(substringRange)
            }
        }
        
        // Check if the active paragraph index is valid
        if activeParagraphIndex < paragraphRanges.count {
            let paragraphRange = paragraphRanges[activeParagraphIndex]
            
            // Create new text with the image marker inserted at the end of the active paragraph
            var newText = currentText
            let insertionPoint = paragraphRange.location + paragraphRange.length
            
            // Convert to Swift String index
            let swiftString = currentText as String
            if insertionPoint <= swiftString.count {
                let insertIndex = swiftString.index(swiftString.startIndex, offsetBy: insertionPoint)
                newText.insert(contentsOf: imageMarker, at: insertIndex)
                
                // Update text
                text = newText
                
                // Simulate a calculation and update
                simulateImageCalculation(imageMarker: imageMarker)
            } else {
                // Fallback: append at end
                insertImageAtEnd(image)
            }
        } else {
            // If the active paragraph is invalid, just append at the end
            insertImageAtEnd(image)
        }
    }
    
    // Helper to insert image at the end of the text
    private func insertImageAtEnd(_ image: UIImage) {
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
