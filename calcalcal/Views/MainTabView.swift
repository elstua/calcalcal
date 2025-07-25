import SwiftUI

struct MainTabView: View {
    @State private var showProfile = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Navigation
                HeaderNavigation(showProfile: $showProfile)
                    .background(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                
                // Main Content - Diary List or Profile
                if showProfile {
                    ProfileView()
                } else {
                    DiaryListView()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
} 

