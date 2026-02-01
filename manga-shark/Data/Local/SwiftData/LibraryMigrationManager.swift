import Foundation
import SwiftData

@MainActor
final class LibraryMigrationManager {
    static let shared = LibraryMigrationManager()

    private let migrationKey = "localLibraryMigrationComplete"

    private init() {}

    var isMigrationNeeded: Bool {
        !UserDefaults.standard.bool(forKey: migrationKey)
    }

    func migrateIfNeeded() async {
        guard isMigrationNeeded else {
            print("📚 [LibraryMigration] Migration already complete, skipping")
            return
        }

        print("📚 [LibraryMigration] Starting library migration from server to local storage")

        do {
            // Fetch library from server
            let serverLibrary = try await LibraryRepository.shared.getLibrary(forceRefresh: true)

            guard !serverLibrary.isEmpty else {
                print("📚 [LibraryMigration] Server library is empty, marking migration complete")
                markMigrationComplete()
                return
            }

            print("📚 [LibraryMigration] Found \(serverLibrary.count) manga to migrate")

            // Migrate each manga with its chapters
            var migratedCount = 0
            var failedCount = 0

            for manga in serverLibrary {
                do {
                    // Fetch chapters for this manga
                    let chapters = try await MangaRepository.shared.getChapters(mangaId: manga.id)

                    // Save to local library
                    try LocalLibraryRepository.shared.addToLibrary(manga: manga, chapters: chapters)

                    migratedCount += 1
                    print("✅ [LibraryMigration] Migrated '\(manga.title)' with \(chapters.count) chapters")
                } catch {
                    failedCount += 1
                    print("❌ [LibraryMigration] Failed to migrate '\(manga.title)': \(error)")
                }
            }

            print("📚 [LibraryMigration] Migration complete: \(migratedCount) succeeded, \(failedCount) failed")

            // Mark migration complete even if some failed - user can re-add manually
            markMigrationComplete()

        } catch {
            print("❌ [LibraryMigration] Failed to fetch server library: \(error)")
            // Don't mark complete on total failure - will retry next launch
        }
    }

    func resetMigration() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
        print("📚 [LibraryMigration] Migration flag reset")
    }

    private func markMigrationComplete() {
        UserDefaults.standard.set(true, forKey: migrationKey)
        print("📚 [LibraryMigration] Migration marked as complete")
    }
}
