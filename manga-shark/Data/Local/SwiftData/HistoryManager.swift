import Foundation
import SwiftData

// MARK: - iOS 17+ SwiftData Implementation

@available(iOS 17, *)
@MainActor
final class HistoryManageriOS17 {
    static let shared = HistoryManageriOS17()
    private var container: ModelContainer?

    private init() {}

    func configure(with container: ModelContainer) {
        self.container = container
    }

    @MainActor
    func recordReading(
        mangaId: String,
        chapterId: String,
        seriesName: String,
        chapterName: String,
        chapterNumber: Double,
        thumbnailUrl: String?,
        progressPercentage: Double,
        lastPageIndex: Int
    ) async {
        guard let container = container else { return }

        let context = container.mainContext
        let descriptor = FetchDescriptor<ReadingHistory>(
            predicate: #Predicate { $0.mangaId == mangaId }
        )

        do {
            let existingEntries = try context.fetch(descriptor)

            if let existing = existingEntries.first {
                // Update existing entry
                existing.chapterId = chapterId
                existing.chapterName = chapterName
                existing.chapterNumber = chapterNumber
                existing.thumbnailUrl = thumbnailUrl
                existing.lastReadDate = Date()
                existing.progressPercentage = progressPercentage
                existing.lastPageIndex = lastPageIndex
            } else {
                // Create new entry
                let entry = ReadingHistory(
                    mangaId: mangaId,
                    chapterId: chapterId,
                    seriesName: seriesName,
                    chapterName: chapterName,
                    chapterNumber: chapterNumber,
                    thumbnailUrl: thumbnailUrl,
                    lastReadDate: Date(),
                    progressPercentage: progressPercentage,
                    lastPageIndex: lastPageIndex
                )
                context.insert(entry)
            }

            try context.save()
        } catch {
            print("⚠️ [HistoryManager] Failed to record reading: \(error)")
        }
    }

    @MainActor
    func deleteEntry(mangaId: String) async {
        guard let container = container else { return }

        let context = container.mainContext
        let descriptor = FetchDescriptor<ReadingHistory>(
            predicate: #Predicate { $0.mangaId == mangaId }
        )

        do {
            let entries = try context.fetch(descriptor)
            for entry in entries {
                context.delete(entry)
            }
            try context.save()
        } catch {
            print("⚠️ [HistoryManager] Failed to delete entry: \(error)")
        }
    }

    @MainActor
    func clearAllHistory() async {
        guard let container = container else { return }

        let context = container.mainContext
        let descriptor = FetchDescriptor<ReadingHistory>()

        do {
            let entries = try context.fetch(descriptor)
            for entry in entries {
                context.delete(entry)
            }
            try context.save()
        } catch {
            print("⚠️ [HistoryManager] Failed to clear history: \(error)")
        }
    }

    @MainActor
    func getAllHistory() async -> [HistoryEntry] {
        guard let container = container else { return [] }

        let context = container.mainContext
        var descriptor = FetchDescriptor<ReadingHistory>(
            sortBy: [SortDescriptor(\.lastReadDate, order: .reverse)]
        )
        descriptor.fetchLimit = 100

        do {
            let entries = try context.fetch(descriptor)
            return entries.map { entry in
                HistoryEntry(
                    mangaId: entry.mangaId,
                    chapterId: entry.chapterId,
                    seriesName: entry.seriesName,
                    chapterName: entry.chapterName,
                    chapterNumber: entry.chapterNumber,
                    thumbnailUrl: entry.thumbnailUrl,
                    lastReadDate: entry.lastReadDate,
                    progressPercentage: entry.progressPercentage,
                    lastPageIndex: entry.lastPageIndex
                )
            }
        } catch {
            print("⚠️ [HistoryManager] Failed to fetch history: \(error)")
            return []
        }
    }
}

// MARK: - iOS 16 UserDefaults Fallback

final class HistoryStorageiOS16 {
    static let shared = HistoryStorageiOS16()
    private let historyKey = "readingHistory"
    private let maxEntries = 100

    private init() {}

    func recordReading(
        mangaId: String,
        chapterId: String,
        seriesName: String,
        chapterName: String,
        chapterNumber: Double,
        thumbnailUrl: String?,
        progressPercentage: Double,
        lastPageIndex: Int
    ) {
        var entries = getAllEntries()

        // Remove existing entry for this manga
        entries.removeAll { $0.mangaId == mangaId }

        // Add new entry at the beginning
        let newEntry = HistoryEntry(
            mangaId: mangaId,
            chapterId: chapterId,
            seriesName: seriesName,
            chapterName: chapterName,
            chapterNumber: chapterNumber,
            thumbnailUrl: thumbnailUrl,
            lastReadDate: Date(),
            progressPercentage: progressPercentage,
            lastPageIndex: lastPageIndex
        )
        entries.insert(newEntry, at: 0)

        // Keep only the most recent entries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        saveEntries(entries)
    }

    func deleteEntry(mangaId: String) {
        var entries = getAllEntries()
        entries.removeAll { $0.mangaId == mangaId }
        saveEntries(entries)
    }

    func clearAllHistory() {
        UserDefaults.standard.removeObject(forKey: historyKey)
    }

    func getAllEntries() -> [HistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([HistoryEntry].self, from: data)
        } catch {
            print("⚠️ [HistoryStorageiOS16] Failed to decode history: \(error)")
            return []
        }
    }

    private func saveEntries(_ entries: [HistoryEntry]) {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: historyKey)
        } catch {
            print("⚠️ [HistoryStorageiOS16] Failed to save history: \(error)")
        }
    }
}

// MARK: - Cross-Platform Wrapper

@MainActor
final class HistoryManager {
    static let shared = HistoryManager()

    private init() {}

    func recordReading(
        mangaId: String,
        chapterId: String,
        seriesName: String,
        chapterName: String,
        chapterNumber: Double,
        thumbnailUrl: String?,
        progressPercentage: Double,
        lastPageIndex: Int
    ) async {
        if #available(iOS 17, *) {
            await HistoryManageriOS17.shared.recordReading(
                mangaId: mangaId,
                chapterId: chapterId,
                seriesName: seriesName,
                chapterName: chapterName,
                chapterNumber: chapterNumber,
                thumbnailUrl: thumbnailUrl,
                progressPercentage: progressPercentage,
                lastPageIndex: lastPageIndex
            )
        } else {
            HistoryStorageiOS16.shared.recordReading(
                mangaId: mangaId,
                chapterId: chapterId,
                seriesName: seriesName,
                chapterName: chapterName,
                chapterNumber: chapterNumber,
                thumbnailUrl: thumbnailUrl,
                progressPercentage: progressPercentage,
                lastPageIndex: lastPageIndex
            )
        }
    }

    func deleteEntry(mangaId: String) async {
        if #available(iOS 17, *) {
            await HistoryManageriOS17.shared.deleteEntry(mangaId: mangaId)
        } else {
            HistoryStorageiOS16.shared.deleteEntry(mangaId: mangaId)
        }
    }

    func clearAllHistory() async {
        if #available(iOS 17, *) {
            await HistoryManageriOS17.shared.clearAllHistory()
        } else {
            HistoryStorageiOS16.shared.clearAllHistory()
        }
    }

    func getAllHistory() async -> [HistoryEntry] {
        if #available(iOS 17, *) {
            return await HistoryManageriOS17.shared.getAllHistory()
        } else {
            return HistoryStorageiOS16.shared.getAllEntries()
        }
    }
}

// MARK: - Shared Data Model

struct HistoryEntry: Codable, Identifiable, Hashable {
    var id: String { mangaId }

    let mangaId: String
    let chapterId: String
    let seriesName: String
    let chapterName: String
    let chapterNumber: Double
    let thumbnailUrl: String?
    let lastReadDate: Date
    let progressPercentage: Double
    let lastPageIndex: Int
}
