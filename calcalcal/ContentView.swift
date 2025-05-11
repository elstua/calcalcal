import SwiftUI
import UIKit

struct ContentView: View {
    @State private var text = ""
    @State private var totalCalories = 0
    @State private var isEditing = false
    // @State private var showingImagePicker = false
    @State private var actualInsertImageTrigger: Int = 0
    
    // Store editor controls
    // @State private var editorControls: BlockEditorControls?
    
    // Configuration for block layout
    // private let blockConfig = BlockLayoutConfig(...)
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("CalCalCal")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Button to insert a calorie marker
                // Button(action: {
                //     actualInsertCalorieMarkerTrigger += 1
                // }) {
                //     Image(systemName: "flame.circle")
                //         .font(.system(size: 20))
                //         .foregroundColor(.orange)
                // }
                // .padding(.trailing, 8)
                
                // Optional: Add a button to insert a text block manually
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
            
            // Main editor area
            CalorieTextEditor(
                text: $text,
                totalCalories: $totalCalories,
                isEditing: $isEditing,
                insertTrigger: $actualInsertImageTrigger,
                calculateCalories: { text, completion in
                    CalorieCalculationService.shared.calculateCaloriesFor(
                        text: text,
                        completion: completion
                    )
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                Group {
                    if text.isEmpty && !isEditing {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Start writing what you eat...")
                                .foregroundColor(.gray)
                                .font(.system(size: 18))
                            
                            Text("Each line becomes a tracked item with calories")
                                .foregroundColor(.gray.opacity(0.7))
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .allowsHitTesting(false)
                    }
                }
            )
            // .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
            //     if text.isEmpty && editorControls != nil {
            //         editorControls?.addTextBlock()
            //     }
            // }
            
            // Footer with total calories
            HStack {
                // Add button for images
                // Button(action: {
                //     showingImagePicker = true
                // }) {
                //     HStack(spacing: 6) {
                //         Image(systemName: "plus.circle.fill")
                //             .font(.system(size: 24))
                //             .foregroundColor(.orange)
                //         
                //         Text("Add Photo")
                //             .font(.caption)
                //             .foregroundColor(.orange)
                //     }
                // }
                // .padding(.leading)
                
                Spacer()
                
                // Total calories
                HStack(spacing: 8) {
                    if totalCalories > 0 {
                        Text("Total:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Text("\(totalCalories) kcal")
                        .font(.headline)
                        .foregroundColor(totalCalories > 0 ? Color(UIColor.label) : .gray)
                }
                .padding(.trailing)
            }
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: -1)
        }
        // .sheet(isPresented: $showingImagePicker) {
        //     ImagePickerView(isPresented: $showingImagePicker) { image in
        //         handleSelectedImage(image)
        //     }
        // }
    }
    
    // MARK: - Private Methods
    
    // private func handleSelectedImage(_ image: UIImage) {
    //     // Add image block with no caption initially
    //     // editorControls?.addImageBlock(image, nil)
    // }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
