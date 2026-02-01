import Foundation
import SwiftData

@available(iOS 17, *)
@Model
final class ReadingHistory: Hashable {
    @Attribute(.unique) var mangaId: String
    var chapterId: String
    var seriesName: String
    var chapterName: String
    var chapterNumber: Double
    var thumbnailUrl: String?
    var lastReadDate: Date
    var progressPercentage: Double
    var lastPageIndex: Int

    init(
        mangaId: String,
        chapterId: String,
        seriesName: String,
        chapterName: String,
        chapterNumber: Double,
        thumbnailUrl: String? = nil,
        lastReadDate: Date = Date(),
        progressPercentage: Double = 0.0,
        lastPageIndex: Int = 0
    ) {
        self.mangaId = mangaId
        self.chapterId = chapterId
        self.seriesName = seriesName
        self.chapterName = chapterName
        self.chapterNumber = chapterNumber
        self.thumbnailUrl = thumbnailUrl
        self.lastReadDate = lastReadDate
        self.progressPercentage = progressPercentage
        self.lastPageIndex = lastPageIndex
    }

    static func == (lhs: ReadingHistory, rhs: ReadingHistory) -> Bool {
        lhs.mangaId == rhs.mangaId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(mangaId)
    }
}
