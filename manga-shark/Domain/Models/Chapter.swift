import Foundation

struct Chapter: Identifiable, Hashable {
    let id: Int
    let mangaId: Int
    let url: String
    let name: String
    let scanlator: String?
    let chapterNumber: Double
    let sourceOrder: Int
    let uploadDate: Date?
    let isRead: Bool
    let isBookmarked: Bool
    let isDownloaded: Bool
    let lastPageRead: Int
    let pageCount: Int
    let realUrl: String?
    let fetchedAt: Date?

    init(
        id: Int,
        mangaId: Int,
        url: String,
        name: String,
        scanlator: String? = nil,
        chapterNumber: Double = 0,
        sourceOrder: Int = 0,
        uploadDate: Date? = nil,
        isRead: Bool = false,
        isBookmarked: Bool = false,
        isDownloaded: Bool = false,
        lastPageRead: Int = 0,
        pageCount: Int = 0,
        realUrl: String? = nil,
        fetchedAt: Date? = nil
    ) {
        self.id = id
        self.mangaId = mangaId
        self.url = url
        self.name = name
        self.scanlator = scanlator
        self.chapterNumber = chapterNumber
        self.sourceOrder = sourceOrder
        self.uploadDate = uploadDate
        self.isRead = isRead
        self.isBookmarked = isBookmarked
        self.isDownloaded = isDownloaded
        self.lastPageRead = lastPageRead
        self.pageCount = pageCount
        self.realUrl = realUrl
        self.fetchedAt = fetchedAt
    }

    var displayName: String {
        if name.isEmpty {
            return "Chapter \(chapterNumber.formatted())"
        }
        return name
    }
}

extension Chapter {
    static func preview(id: Int = 1, mangaId: Int = 1) -> Chapter {
        Chapter(
            id: id,
            mangaId: mangaId,
            url: "/manga/1/chapter/\(id)",
            name: "Chapter \(id)",
            chapterNumber: Double(id),
            sourceOrder: id,
            pageCount: 20
        )
    }
}
