import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            LibraryView()
                .tabItem {
                    Label(AppState.Tab.library.title, systemImage: AppState.Tab.library.icon)
                }
                .tag(AppState.Tab.library)

            SourcesListView()
                .tabItem {
                    Label(AppState.Tab.browse.title, systemImage: AppState.Tab.browse.icon)
                }
                .tag(AppState.Tab.browse)

            HistoryView()
                .tabItem {
                    Label(AppState.Tab.history.title, systemImage: AppState.Tab.history.icon)
                }
                .tag(AppState.Tab.history)

            DownloadsView()
                .tabItem {
                    Label(AppState.Tab.downloads.title, systemImage: AppState.Tab.downloads.icon)
                }
                .tag(AppState.Tab.downloads)

            SettingsView()
                .tabItem {
                    Label(AppState.Tab.settings.title, systemImage: AppState.Tab.settings.icon)
                }
                .tag(AppState.Tab.settings)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState.shared)
}
