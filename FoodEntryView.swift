import SwiftUI

struct FoodEntryView: View {
    // The food entry this view represents
    let entry: FoodEntry
    
    // Focus state
    @Binding var focusedEntryId: UUID?
    
    // Callbacks
    var onTextChanged: (String) -> Void
    var onImageTapped: () -> Void
    var onDeleteTapped: () -> Void
    
    // Calculate if this entry is focused
    private var isFocused: Bool {
        focusedEntryId == entry.id
    }
    
    // Text to display in the editor
    @State private var localText: String = ""
    
    // Initialize local state from props
    private func initializeState() {
        if localText != entry.text {
            localText = entry.text
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left side - Text editor and image (if any)
            VStack(alignment: .leading, spacing: 8) {
                // Text editor
                textEditorView
                
                // Image view (if present)
                if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right side - Calorie information
            calorieView
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedEntryId = entry.id
        }
        .onAppear {
            initializeState()
        }
        .onChange(of: entry.text) { _ in
            initializeState()
        }
    }
    
    // Text editor view
    private var textEditorView: some View {
        ZStack(alignment: .leading) {
            // Placeholder text when empty and not focused
            if localText.isEmpty && !isFocused {
                Text("Start to write what you eat...")
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
            }
            
            // Actual text editor
            TextEditor(text: $localText)
                .focused($focusedEntryId, equals: entry.id)
                .frame(minHeight: 24)
                .padding(4)
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(6)
                .onChange(of: localText) { newText in
                    onTextChanged(newText)
                }
        }
    }
    
    // Calorie view
    private var calorieView: some View {
        VStack {
            // Show either the calorie value or a placeholder/loading indicator
            if let calories = entry.calories {
                Text("\(calories) kcal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
            } else if !entry.isEmpty {
                // Show loading indicator when calculating
                ProgressView()
                    .frame(width: 80, alignment: .center)
            } else {
                // Show add button for empty entries
                Button(action: onImageTapped) {
                    ZStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 30, height: 30)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 80, alignment: .center)
            }
            
            // Delete button only shows when entry is focused
            if isFocused && !entry.isEmpty {
                Button(action: onDeleteTapped) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .padding(.top, 8)
                .frame(width: 80, alignment: .center)
            }
        }
        .padding(.top, 4)
    }
}