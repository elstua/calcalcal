import SwiftUI

struct HeaderNavigation: View {
    @Binding var showProfile: Bool
    @State private var isProfileOpen: Bool = false
    
    var body: some View {
        HStack {
            Spacer()
            Button(action: {
                isProfileOpen.toggle()
                showProfile = isProfileOpen
            }) {
                Image(systemName: "person.crop.circle")
                    .imageScale(.large)
                    .accessibilityLabel("Profile")
            }
            if isProfileOpen {
                Button(action: {
                    isProfileOpen = false
                    showProfile = false
                }) {
                    Text("Diary")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding()
        .animation(.easeInOut, value: isProfileOpen)
    }
}

// Preview
struct HeaderNavigation_Previews: PreviewProvider {
    static var previews: some View {
        HeaderNavigation(showProfile: .constant(false))
            .previewLayout(.sizeThatFits)
    }
} 
