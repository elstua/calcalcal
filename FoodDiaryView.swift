import SwiftUI

struct FoodDiaryView: View {
    // ViewModel
    @StateObject private var viewModel = FoodDiaryViewModel()
    
    // FocusState for handling text field focus
    @FocusState private var focusedEntryId: UUID?
    
    // Sync ViewModel and FocusState
    private func syncFocusState() {
        viewModel.focusedEntryId = focusedEntryId
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main scrollable content area
            ScrollView {
                VStack(spacing: 0) {
                    // List of food entries
                    ForEach(viewModel.diary.entries) { entry in
                        FoodEntryView(
                            entry: entry,
                            focusedEntryId: Binding(
                                get: { self.focusedEntryId },
                                set: { self.focusedEntryId = $0 }
                            ),
                            onTextChanged: { newText in
                                viewModel.updateEntryText(id: entry.id, newText: newText)
                            },
                            onImageTapped: {
                                // In a real app, you'd show an image picker here
                                print("Would show image picker for entry \(entry.id)")
                            },
                            onDeleteTapped: {
                                viewModel.deleteEntry(id: entry.id)
                            }
                        )
                        .id(entry.id)
                        
                        // Add a divider between entries
                        if entry.id != viewModel.diary.entries.last?.id {
                            Divider()
                                .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom summary bar
            VStack {
                Divider()
                    .background(Color.gray.opacity(0.7))
                
                HStack {
                    Text("Total: \(viewModel.diary.totalCalories) kcal")
                        .font(.headline)
                        .padding()
                    Spacer()
                    
                    // Date display
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                }
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: -1)
            }
        }
        .onChange(of: focusedEntryId) { _ in
            syncFocusState()
        }
    }
    
    // Format the current date for display
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: viewModel.diary.lastUpdatedAt)
    }
}

// Preview for development
struct FoodDiaryView_Previews: PreviewProvider {
    static var previews: some View {
        FoodDiaryView()
    }
}