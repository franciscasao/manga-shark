import Foundation

struct Manga: Identifiable, Hashable {
    let id: Int
    let sourceId: String
    let url: String
    let title: String
    let thumbnailUrl: String?
    let artist: String?
    let author: String?
    let description: String?
    let genre: [String]
    let status: MangaStatus
    let inLibrary: Bool
    let inLibraryAt: Date?
    let realUrl: String?
    let lastFetchedAt: Date?
    let chaptersLastFetchedAt: Date?
    let updateStrategy: UpdateStrategy
    let freshData: Bool
    let unreadCount: Int
    let downloadCount: Int
    let chapterCount: Int
    let lastReadChapter: Chapter?
    let latestReadChapter: Chapter?
    let latestFetchedChapter: Chapter?
    let latestUploadedChapter: Chapter?
    let categories: [Category]

    init(
        id: Int,
        sourceId: String,
        url: String,
        title: String,
        thumbnailUrl: String? = nil,
        artist: String? = nil,
        author: String? = nil,
        description: String? = nil,
        genre: [String] = [],
        status: MangaStatus = .unknown,
        inLibrary: Bool = false,
        inLibraryAt: Date? = nil,
        realUrl: String? = nil,
        lastFetchedAt: Date? = nil,
        chaptersLastFetchedAt: Date? = nil,
        updateStrategy: UpdateStrategy = .alwaysUpdate,
        freshData: Bool = false,
        unreadCount: Int = 0,
        downloadCount: Int = 0,
        chapterCount: Int = 0,
        lastReadChapter: Chapter? = nil,
        latestReadChapter: Chapter? = nil,
        latestFetchedChapter: Chapter? = nil,
        latestUploadedChapter: Chapter? = nil,
        categories: [Category] = []
    ) {
        self.id = id
        self.sourceId = sourceId
        self.url = url
        self.title = title
        self.thumbnailUrl = thumbnailUrl
        self.artist = artist
        self.author = author
        self.description = description
        self.genre = genre
        self.status = status
        self.inLibrary = inLibrary
        self.inLibraryAt = inLibraryAt
        self.realUrl = realUrl
        self.lastFetchedAt = lastFetchedAt
        self.chaptersLastFetchedAt = chaptersLastFetchedAt
        self.updateStrategy = updateStrategy
        self.freshData = freshData
        self.unreadCount = unreadCount
        self.downloadCount = downloadCount
        self.chapterCount = chapterCount
        self.lastReadChapter = lastReadChapter
        self.latestReadChapter = latestReadChapter
        self.latestFetchedChapter = latestFetchedChapter
        self.latestUploadedChapter = latestUploadedChapter
        self.categories = categories
    }
}

enum MangaStatus: String, CaseIterable {
    case unknown = "UNKNOWN"
    case ongoing = "ONGOING"
    case completed = "COMPLETED"
    case licensed = "LICENSED"
    case publishingFinished = "PUBLISHING_FINISHED"
    case cancelled = "CANCELLED"
    case onHiatus = "ON_HIATUS"

    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .ongoing: return "Ongoing"
        case .completed: return "Completed"
        case .licensed: return "Licensed"
        case .publishingFinished: return "Publishing Finished"
        case .cancelled: return "Cancelled"
        case .onHiatus: return "On Hiatus"
        }
    }
}

enum UpdateStrategy: String {
    case alwaysUpdate = "ALWAYS_UPDATE"
    case onlyFetchOnce = "ONLY_FETCH_ONCE"
}
