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

    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([ChapterProgress.self, MangaScanlatorFilter.self, ReadingHistory.self, LocalManga.self, LocalChapter.self])
            let configuration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .automatic
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            self.modelContainer = container

            // Configure managers with the container
            Task { @MainActor in
                ReadingProgressManager.shared.configure(with: container)
                ScanlatorFilterManager.shared.configure(with: container)
                HistoryManager.shared.configure(with: container)
                LocalLibraryRepository.shared.configure(with: container)
            }
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .modelContainer(modelContainer)
                .task {
                    await ProgressMigrationManager.shared.migrateIfNeeded(to: modelContainer)
                    // Run library migration after server is configured
                    if appState.isServerConfigured {
                        await LibraryMigrationManager.shared.migrateIfNeeded()
                    }
                }
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
