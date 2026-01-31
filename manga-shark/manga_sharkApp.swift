//
//  manga_sharkApp.swift
//  manga-shark
//
//  Created by Francis Casao on 1/25/26.
//

import SwiftUI
import SwiftData

@main
struct manga_sharkApp: App {
    @StateObject private var appState = AppState.shared

    init() {
        // Configure SwiftData for iOS 17+
        if #available(iOS 17, *) {
            Self.configureSwiftData()
        }
    }

    @available(iOS 17, *)
    private static func configureSwiftData() {
        do {
            let schema = Schema([ChapterProgress.self])
            let configuration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .automatic
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])

            // Store container for later use
            SwiftDataContainerHolder.shared.container = container

            // Configure ReadingProgressManager with the container
            Task { @MainActor in
                ReadingProgressManageriOS17.shared.configure(with: container)
            }
        } catch {
            print("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            if #available(iOS 17, *), let container = SwiftDataContainerHolder.shared.container {
                RootView()
                    .environmentObject(appState)
                    .modelContainer(container)
                    .task {
                        await ProgressMigrationManager.shared.migrateIfNeeded(to: container)
                    }
            } else {
                RootView()
                    .environmentObject(appState)
            }
        }
    }
}

/// Holder for SwiftData container to work around @available limitations
@available(iOS 17, *)
final class SwiftDataContainerHolder {
    static let shared = SwiftDataContainerHolder()
    var container: ModelContainer?
    private init() {}
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
