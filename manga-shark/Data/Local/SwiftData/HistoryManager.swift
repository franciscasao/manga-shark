import Foundation
import SwiftData

// MARK: - History Manager

@MainActor
final class HistoryManager {
    static let shared = HistoryManager()
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
