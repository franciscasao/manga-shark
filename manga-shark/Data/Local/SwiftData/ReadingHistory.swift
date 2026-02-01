import Foundation
import SwiftData

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

// MARK: - Preview Helpers

extension ReadingHistory {
    static var preview: ReadingHistory {
        ReadingHistory(
            mangaId: "1",
            chapterId: "100",
            seriesName: "One Piece",
            chapterName: "Romance Dawn",
            chapterNumber: 1.0,
            thumbnailUrl: nil,
            lastReadDate: Date(),
            progressPercentage: 0.75,
            lastPageIndex: 15
        )
    }

    static var previewList: [ReadingHistory] {
        [
            ReadingHistory(
                mangaId: "1",
                chapterId: "100",
                seriesName: "One Piece",
                chapterName: "Romance Dawn",
                chapterNumber: 1.0,
                progressPercentage: 0.75
            ),
            ReadingHistory(
                mangaId: "2",
                chapterId: "200",
                seriesName: "Naruto",
                chapterName: "Uzumaki Naruto",
                chapterNumber: 1.0,
                lastReadDate: Date().addingTimeInterval(-3600),
                progressPercentage: 1.0
            ),
            ReadingHistory(
                mangaId: "3",
                chapterId: "300",
                seriesName: "Bleach",
                chapterName: "Death and Strawberry",
                chapterNumber: 1.0,
                lastReadDate: Date().addingTimeInterval(-86400),
                progressPercentage: 0.5
            ),
        ]
    }
}
