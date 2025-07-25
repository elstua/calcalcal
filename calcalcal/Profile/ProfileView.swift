import SwiftUI

struct ProfileView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Name as big header
            Text("Artem Savelev")
                .font(.largeTitle)
                .fontWeight(.regular)
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Email placeholder
            Text("artem.savelev@example.com")
                .font(.title3)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Sign out button at the bottom
            Button(action: {
                // Sign out action - will be implemented later
                print("Sign out tapped")
            }) {
                Text("Sign Out")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
