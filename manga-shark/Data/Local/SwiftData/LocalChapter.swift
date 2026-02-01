import Foundation
import SwiftData

@Model
final class LocalChapter {
    @Attribute(.unique) var serverId: Int
    var url: String
    var name: String
    var scanlator: String?
    var chapterNumber: Double
    var sourceOrder: Int
    var uploadDate: Date?
    var pageCount: Int
    var addedAt: Date

    var manga: LocalManga?

    init(
        serverId: Int,
        url: String,
        name: String,
        scanlator: String? = nil,
        chapterNumber: Double = 0,
        sourceOrder: Int = 0,
        uploadDate: Date? = nil,
        pageCount: Int = 0,
        addedAt: Date = Date()
    ) {
        self.serverId = serverId
        self.url = url
        self.name = name
        self.scanlator = scanlator
        self.chapterNumber = chapterNumber
        self.sourceOrder = sourceOrder
        self.uploadDate = uploadDate
        self.pageCount = pageCount
        self.addedAt = addedAt
    }
}
