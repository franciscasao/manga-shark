import Foundation
import SwiftData

@MainActor
final class LocalLibraryRepository {
    static let shared = LocalLibraryRepository()

    private var modelContainer: ModelContainer?

    private init() {}

    // MARK: - Configuration

    func configure(with container: ModelContainer) {
        self.modelContainer = container
    }

    // MARK: - Library Operations

    func getLibrary() -> [LocalManga] {
        guard let container = modelContainer else {
            print("⚠️ [LocalLibraryRepository] ModelContainer not configured")
            return []
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<LocalManga>(
            sortBy: [SortDescriptor(\.title)]
        )

        do {
            let results = try context.fetch(descriptor)
            print("📚 [LocalLibraryRepository] Fetched \(results.count) manga from local library")
            return results
        } catch {
            print("❌ [LocalLibraryRepository] Failed to fetch library: \(error)")
            return []
        }
    }

    func isInLibrary(mangaId: Int) -> Bool {
        guard let container = modelContainer else { return false }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<LocalManga>(
            predicate: #Predicate { $0.serverId == mangaId }
        )

        do {
            let results = try context.fetch(descriptor)
            return !results.isEmpty
        } catch {
            print("⚠️ [LocalLibraryRepository] Failed to check library status: \(error)")
            return false
        }
    }

    func getManga(id: Int) -> LocalManga? {
        guard let container = modelContainer else { return nil }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<LocalManga>(
            predicate: #Predicate { $0.serverId == id }
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            print("⚠️ [LocalLibraryRepository] Failed to fetch manga \(id): \(error)")
            return nil
        }
    }

    func getChapters(mangaId: Int) -> [LocalChapter] {
        guard let manga = getManga(id: mangaId) else { return [] }
        return manga.chapters.sorted { $0.sourceOrder < $1.sourceOrder }
    }

    // MARK: - Add/Remove Operations

    func addToLibrary(manga: Manga, chapters: [Chapter]) throws {
        guard let container = modelContainer else {
            throw LocalLibraryError.notConfigured
        }

        let context = ModelContext(container)

        // Check if already in library
        let mangaServerId = manga.id
        let descriptor = FetchDescriptor<LocalManga>(
            predicate: #Predicate { $0.serverId == mangaServerId }
        )
        let existing = try context.fetch(descriptor)

        if !existing.isEmpty {
            print("📚 [LocalLibraryRepository] Manga \(manga.id) already in library")
            return
        }

        // Create local manga
        let localManga = manga.toLocalManga()

        // Create local chapters and associate them
        let localChapters = chapters.map { $0.toLocalChapter() }
        for chapter in localChapters {
            chapter.manga = localManga
        }
        localManga.chapters = localChapters

        context.insert(localManga)

        try context.save()
        print("✅ [LocalLibraryRepository] Added manga '\(manga.title)' with \(chapters.count) chapters to library")
    }

    func removeFromLibrary(mangaId: Int) throws {
        guard let container = modelContainer else {
            throw LocalLibraryError.notConfigured
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<LocalManga>(
            predicate: #Predicate { $0.serverId == mangaId }
        )

        let results = try context.fetch(descriptor)

        for manga in results {
            context.delete(manga)
        }

        try context.save()
        print("✅ [LocalLibraryRepository] Removed manga \(mangaId) from library")
    }

    // MARK: - Chapter Refresh

    func refreshChapters(mangaId: Int, remoteChapters: [Chapter]) throws {
        guard let container = modelContainer else {
            throw LocalLibraryError.notConfigured
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<LocalManga>(
            predicate: #Predicate { $0.serverId == mangaId }
        )

        let results = try context.fetch(descriptor)

        guard let localManga = results.first else {
            print("⚠️ [LocalLibraryRepository] Manga \(mangaId) not in local library")
            return
        }

        // Get existing chapter IDs
        let existingChapterIds = Set(localManga.chapters.map { $0.serverId })

        // Find new chapters
        let newChapters = remoteChapters.filter { !existingChapterIds.contains($0.id) }

        if newChapters.isEmpty {
            print("📚 [LocalLibraryRepository] No new chapters for manga \(mangaId)")
            return
        }

        // Add new chapters
        for chapter in newChapters {
            let localChapter = chapter.toLocalChapter()
            localChapter.manga = localManga
            localManga.chapters.append(localChapter)
        }

        localManga.lastRefreshedAt = Date()

        try context.save()
        print("✅ [LocalLibraryRepository] Added \(newChapters.count) new chapters to manga \(mangaId)")
    }

    // MARK: - Bulk Operations

    func addMultipleToLibrary(items: [(manga: Manga, chapters: [Chapter])]) throws {
        guard let container = modelContainer else {
            throw LocalLibraryError.notConfigured
        }

        let context = ModelContext(container)

        for (manga, chapters) in items {
            // Check if already exists
            let mangaServerId = manga.id
            let descriptor = FetchDescriptor<LocalManga>(
                predicate: #Predicate { $0.serverId == mangaServerId }
            )
            let existing = try context.fetch(descriptor)

            if !existing.isEmpty {
                continue
            }

            let localManga = manga.toLocalManga()
            let localChapters = chapters.map { $0.toLocalChapter() }

            for chapter in localChapters {
                chapter.manga = localManga
            }
            localManga.chapters = localChapters

            context.insert(localManga)
        }

        try context.save()
        print("✅ [LocalLibraryRepository] Bulk added \(items.count) manga to library")
    }
}

// MARK: - Errors

enum LocalLibraryError: Error, LocalizedError {
    case notConfigured
    case mangaNotFound

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Local library repository not configured"
        case .mangaNotFound:
            return "Manga not found in local library"
        }
    }
}
