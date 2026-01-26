import Foundation
import CoreData

actor ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, NSData>()
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    private init() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    func getImage(for url: String) async -> Data? {
        // Check memory cache first
        if let data = memoryCache.object(forKey: url as NSString) {
            return data as Data
        }

        // Check disk cache
        if let data = await loadFromDisk(url: url) {
            memoryCache.setObject(data as NSData, forKey: url as NSString)
            return data
        }

        return nil
    }

    func cacheImage(_ data: Data, for url: String) async {
        memoryCache.setObject(data as NSData, forKey: url as NSString)
        await saveToDisk(data: data, url: url)
    }

    private func loadFromDisk(url: String) async -> Data? {
        do {
            return try await CoreDataStack.shared.performBackgroundTask { context in
                let request = NSFetchRequest<CachedImage>(entityName: "CachedImage")
                request.predicate = NSPredicate(format: "url == %@", url)
                request.fetchLimit = 1

                guard let cached = try context.fetch(request).first,
                      let data = cached.data else {
                    return nil
                }

                // Check if cache is still valid
                if let cachedAt = cached.cachedAt,
                   Date().timeIntervalSince(cachedAt) > self.maxCacheAge {
                    context.delete(cached)
                    try context.save()
                    return nil
                }

                return data
            }
        } catch {
            return nil
        }
    }

    private func saveToDisk(data: Data, url: String) async {
        do {
            try await CoreDataStack.shared.performBackgroundTask { context in
                let request = NSFetchRequest<CachedImage>(entityName: "CachedImage")
                request.predicate = NSPredicate(format: "url == %@", url)
                request.fetchLimit = 1

                let cached: CachedImage
                if let existing = try context.fetch(request).first {
                    cached = existing
                } else {
                    cached = CachedImage(context: context)
                    cached.url = url
                }

                cached.data = data
                cached.cachedAt = Date()

                try context.save()
            }
        } catch {
            // Silently fail for cache operations
        }
    }

    func clearCache() async {
        memoryCache.removeAllObjects()

        do {
            try await CoreDataStack.shared.performBackgroundTask { context in
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: "CachedImage")
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                try context.execute(deleteRequest)
            }
        } catch {
            // Silently fail
        }
    }

    func clearExpiredCache() async {
        let cutoffDate = Date().addingTimeInterval(-maxCacheAge)

        do {
            try await CoreDataStack.shared.performBackgroundTask { context in
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: "CachedImage")
                request.predicate = NSPredicate(format: "cachedAt < %@", cutoffDate as NSDate)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                try context.execute(deleteRequest)
            }
        } catch {
            // Silently fail
        }
    }

    func cacheSize() async -> Int64 {
        do {
            return try await CoreDataStack.shared.performBackgroundTask { context in
                let request = NSFetchRequest<CachedImage>(entityName: "CachedImage")
                let images = try context.fetch(request)
                return images.reduce(0) { $0 + Int64($1.data?.count ?? 0) }
            }
        } catch {
            return 0
        }
    }
}

// MARK: - File-based Storage for Downloaded Chapters

actor DownloadStorage {
    static let shared = DownloadStorage()

    private let fileManager = FileManager.default

    nonisolated private var downloadsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Downloads", isDirectory: true)
    }

    private init() {
        try? FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
    }

    nonisolated func chapterDirectory(mangaId: Int, chapterId: Int) -> URL {
        downloadsDirectory
            .appendingPathComponent("manga_\(mangaId)", isDirectory: true)
            .appendingPathComponent("chapter_\(chapterId)", isDirectory: true)
    }

    func savePageImage(_ data: Data, mangaId: Int, chapterId: Int, pageIndex: Int) async throws {
        let directory = chapterDirectory(mangaId: mangaId, chapterId: chapterId)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileUrl = directory.appendingPathComponent("page_\(pageIndex).jpg")
        try data.write(to: fileUrl)
    }

    func getPageImage(mangaId: Int, chapterId: Int, pageIndex: Int) async -> Data? {
        let fileUrl = chapterDirectory(mangaId: mangaId, chapterId: chapterId)
            .appendingPathComponent("page_\(pageIndex).jpg")
        return fileManager.contents(atPath: fileUrl.path)
    }

    func isChapterDownloaded(mangaId: Int, chapterId: Int) -> Bool {
        let directory = chapterDirectory(mangaId: mangaId, chapterId: chapterId)
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    func deleteChapter(mangaId: Int, chapterId: Int) async throws {
        let directory = chapterDirectory(mangaId: mangaId, chapterId: chapterId)
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
    }

    func deleteManga(mangaId: Int) async throws {
        let directory = downloadsDirectory.appendingPathComponent("manga_\(mangaId)", isDirectory: true)
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
    }

    func clearAllDownloads() async throws {
        if fileManager.fileExists(atPath: downloadsDirectory.path) {
            try fileManager.removeItem(at: downloadsDirectory)
            try fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        }
    }

    func totalDownloadSize() async -> Int64 {
        guard let enumerator = fileManager.enumerator(at: downloadsDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }

        return totalSize
    }
}
