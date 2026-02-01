import Foundation

actor ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, NSData>()
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    private let fileManager = FileManager.default

    private var cacheDirectory: URL {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("ImageCache", isDirectory: true)
    }

    private init() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB

        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
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

    private func fileURL(for url: String) -> URL {
        // Create a safe filename from URL using hash
        let filename = url.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .prefix(100) ?? "unknown"
        return cacheDirectory.appendingPathComponent(String(filename))
    }

    private func loadFromDisk(url: String) async -> Data? {
        let fileUrl = fileURL(for: url)

        guard fileManager.fileExists(atPath: fileUrl.path) else {
            return nil
        }

        // Check if cache is still valid
        if let attributes = try? fileManager.attributesOfItem(atPath: fileUrl.path),
           let modificationDate = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modificationDate) > maxCacheAge {
            try? fileManager.removeItem(at: fileUrl)
            return nil
        }

        return fileManager.contents(atPath: fileUrl.path)
    }

    private func saveToDisk(data: Data, url: String) async {
        let fileUrl = fileURL(for: url)
        try? data.write(to: fileUrl)
    }

    func clearCache() async {
        memoryCache.removeAllObjects()

        if let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    func clearExpiredCache() async {
        let cutoffDate = Date().addingTimeInterval(-maxCacheAge)

        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }

        for file in files {
            if let attributes = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
               let modificationDate = attributes.contentModificationDate,
               modificationDate < cutoffDate {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    func cacheSize() async -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0
        for file in files {
            if let attributes = try? file.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = attributes.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        return totalSize
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
