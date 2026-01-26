import Foundation

actor DownloadManager {
    static let shared = DownloadManager()

    private(set) var activeDownloads: [Int: DownloadTask] = [:]
    private(set) var isRunning = false

    private var downloadQueue: [DownloadRequest] = []

    struct DownloadRequest {
        let chapter: Chapter
        let manga: Manga
    }

    struct DownloadTask {
        let chapterId: Int
        let mangaId: Int
        let chapterName: String
        let mangaTitle: String
        var progress: Double
        var status: Status
        var error: Error?

        enum Status {
            case queued
            case downloading
            case completed
            case failed
        }
    }

    private init() {}

    func enqueueChapter(_ chapter: Chapter, manga: Manga) async {
        // Check if already downloaded or in queue
        if await DownloadStorage.shared.isChapterDownloaded(mangaId: manga.id, chapterId: chapter.id) {
            return
        }

        if activeDownloads[chapter.id] != nil || downloadQueue.contains(where: { $0.chapter.id == chapter.id }) {
            return
        }

        downloadQueue.append(DownloadRequest(chapter: chapter, manga: manga))

        if isRunning {
            await processQueue()
        }
    }

    func enqueueChapters(_ chapters: [Chapter], manga: Manga) async {
        for chapter in chapters {
            await enqueueChapter(chapter, manga: manga)
        }
    }

    func start() async {
        guard !isRunning else { return }
        isRunning = true
        await processQueue()
    }

    func stop() {
        isRunning = false
    }

    func cancelDownload(chapterId: Int) async {
        activeDownloads.removeValue(forKey: chapterId)
        downloadQueue.removeAll { $0.chapter.id == chapterId }
    }

    func clearQueue() async {
        downloadQueue.removeAll()
        activeDownloads.removeAll()
    }

    private func processQueue() async {
        while isRunning && !downloadQueue.isEmpty {
            let request = downloadQueue.removeFirst()
            await downloadChapter(request)
        }
    }

    private func downloadChapter(_ request: DownloadRequest) async {
        let chapter = request.chapter
        let manga = request.manga

        var task = DownloadTask(
            chapterId: chapter.id,
            mangaId: manga.id,
            chapterName: chapter.displayName,
            mangaTitle: manga.title,
            progress: 0,
            status: .downloading
        )
        activeDownloads[chapter.id] = task

        do {
            // Get chapter pages
            let pages = try await ChapterRepository.shared.getChapterPages(chapterId: chapter.id)

            guard !pages.isEmpty else {
                throw DownloadError.noPages
            }

            // Download each page
            for (index, page) in pages.enumerated() {
                guard isRunning else {
                    task.status = .queued
                    activeDownloads[chapter.id] = task
                    downloadQueue.insert(request, at: 0)
                    return
                }

                if let url = page.imageUrl {
                    let imageData = try await NetworkClient.shared.fetchImage(from: url)
                    try await DownloadStorage.shared.savePageImage(
                        imageData,
                        mangaId: manga.id,
                        chapterId: chapter.id,
                        pageIndex: index
                    )
                }

                task.progress = Double(index + 1) / Double(pages.count)
                activeDownloads[chapter.id] = task
            }

            task.status = .completed
            task.progress = 1.0
            activeDownloads[chapter.id] = task

            // Remove from active after a short delay
            try? await Task.sleep(nanoseconds: 500_000_000)
            activeDownloads.removeValue(forKey: chapter.id)

        } catch {
            task.status = .failed
            task.error = error
            activeDownloads[chapter.id] = task
        }
    }

    func deleteDownloadedChapter(mangaId: Int, chapterId: Int) async {
        try? await DownloadStorage.shared.deleteChapter(mangaId: mangaId, chapterId: chapterId)
    }

    func getDownloadedPages(mangaId: Int, chapterId: Int) async -> [Page] {
        var pages: [Page] = []
        var index = 0

        while let _ = await DownloadStorage.shared.getPageImage(
            mangaId: mangaId,
            chapterId: chapterId,
            pageIndex: index
        ) {
            let localPath = DownloadStorage.shared.chapterDirectory(mangaId: mangaId, chapterId: chapterId)
                .appendingPathComponent("page_\(index).jpg")
                .path

            pages.append(Page(
                chapterId: chapterId,
                index: index,
                localPath: localPath
            ))
            index += 1
        }

        return pages
    }
}

enum DownloadError: Error, LocalizedError {
    case noPages
    case downloadFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noPages:
            return "No pages available for download"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        }
    }
}
