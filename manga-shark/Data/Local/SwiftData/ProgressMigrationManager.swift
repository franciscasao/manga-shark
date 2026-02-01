import Foundation
import SwiftData

@MainActor
final class ProgressMigrationManager {
    static let shared = ProgressMigrationManager()

    private let migrationKey = "has_migrated_progress_to_swiftdata"

    private init() {}

    var hasMigrated: Bool {
        UserDefaults.standard.bool(forKey: migrationKey)
    }

    func migrateIfNeeded(to container: ModelContainer) async {
        guard !hasMigrated else {
            print("ℹ️ [ProgressMigrationManager] Already migrated, skipping")
            return
        }

        print("🔄 [ProgressMigrationManager] Starting migration...")

        do {
            try await migrateFromUserDefaults(to: container)

            UserDefaults.standard.set(true, forKey: migrationKey)
            print("✅ [ProgressMigrationManager] Migration completed successfully")
        } catch {
            print("⚠️ [ProgressMigrationManager] Migration failed: \(error)")
        }
    }

    private func migrateFromUserDefaults(to container: ModelContainer) async throws {
        let context = ModelContext(container)
        let userDefaults = UserDefaults.standard

        // Find all manhwa scroll percentage keys
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let percentageKeys = allKeys.filter { $0.hasPrefix("manhwa_scroll_offset_percentage_") }

        print("🔄 [ProgressMigrationManager] Found \(percentageKeys.count) manhwa scroll percentages in UserDefaults")

        for key in percentageKeys {
            // Extract chapter ID from key: "manhwa_scroll_offset_percentage_123" -> "123"
            let chapterId = String(key.dropFirst("manhwa_scroll_offset_percentage_".count))

            // Check if we already have progress for this chapter
            let descriptor = FetchDescriptor<ChapterProgress>(
                predicate: #Predicate { $0.chapterId == chapterId }
            )
            let existingResults = try context.fetch(descriptor)

            if existingResults.first != nil {
                // Skip if already exists
                continue
            }

            let percentage = userDefaults.double(forKey: key)
            if percentage > 0 {
                // We don't have seriesId from UserDefaults, use empty string (will be updated on next read)
                let progress = ChapterProgress(
                    chapterId: chapterId,
                    seriesId: "",
                    lastReadPercentage: percentage,
                    updatedAt: Date(),
                    isRead: percentage >= 0.95,
                    lastPageIndex: 0
                )
                context.insert(progress)
            }
        }

        try context.save()

        // Clean up old UserDefaults keys
        for key in percentageKeys {
            userDefaults.removeObject(forKey: key)
        }

        // Also clean up offset keys
        let offsetKeys = allKeys.filter { $0.hasPrefix("manhwa_scroll_offset_") && !$0.contains("percentage") }
        for key in offsetKeys {
            userDefaults.removeObject(forKey: key)
        }

        print("✅ [ProgressMigrationManager] UserDefaults migration completed")
    }
}
