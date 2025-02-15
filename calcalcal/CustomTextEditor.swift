import SwiftUI

struct CustomTextEditor: View {
    @Binding var text: String
    let entries: [Entry]
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Overlay for calories
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(entries) { entry in
                    if let calories = entry.calories {
                        Text("\(calories) kcal")
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .frame(height: 20)
                    }
                }
            }
            .padding(.top, 8)
            .offset(x: UIScreen.main.bounds.width - 100)
        }
    }
}