//
//  manga_sharkApp.swift
//  manga-shark
//
//  Created by Francis Casao on 1/25/26.
//

import SwiftUI

@main
struct manga_sharkApp: App {
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isServerConfigured {
                MainTabView()
            } else {
                ServerSetupView()
            }
        }
        .animation(.easeInOut, value: appState.isServerConfigured)
    }
}
