import SwiftUI

struct BlockEditorTestView: View {
    @State private var text: String = """
    Bulletproof coffee
    ::image::Morning smoothie
    Grilled salmon with quinoa bowl
    Dark chocolate square
    """
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                BlockEditorRepresentable(text: $text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color(uiColor: .separator), lineWidth: 1)
                    )
                
                Text("Current text:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ScrollView {
                    Text(text.isEmpty ? "Start typing above…" : text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .frame(maxHeight: 160)
            }
            .padding(20)
            .navigationTitle("Editor V2 Test")
        }
    }
}


struct BlockEditorTestView_Previews: PreviewProvider {
    static var previews: some View {
        BlockEditorTestView()
    }
}



