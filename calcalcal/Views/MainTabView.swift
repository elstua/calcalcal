import SwiftUI
import UIKit

/// The main tab navigation container for the app.
/// Contains the Diary and Profile tabs.
struct MainTabView: View {
    @EnvironmentObject var appState: AppState


    var body: some View {
        ZStack {
            // Full screen background
            DSColors.background
                .ignoresSafeArea()
            
            TabView {
                DiaryTabView()
                    .tabItem {
                        Image(systemName: "book.fill")
                        Text("Diary")
                    }

                ProfileView()
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Profile")
                    }
            }
        }
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AppState())
    }
}
