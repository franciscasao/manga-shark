import Foundation

struct Page: Identifiable, Hashable {
    let id: Int
    let chapterId: Int
    let index: Int
    let imageUrl: String?
    let localPath: String?

    init(
        id: Int? = nil,
        chapterId: Int,
        index: Int,
        imageUrl: String? = nil,
        localPath: String? = nil
    ) {
        self.id = id ?? index
        self.chapterId = chapterId
        self.index = index
        self.imageUrl = imageUrl
        self.localPath = localPath
    }

    var effectiveUrl: String? {
        localPath ?? imageUrl
    }
}

struct ChapterPages {
    let chapter: Chapter
    let pages: [Page]

    var pageCount: Int {
        pages.count
    }
}
