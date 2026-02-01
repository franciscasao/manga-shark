import Foundation
import SwiftData

@Model
final class ChapterProgress {
    @Attribute(.unique) var chapterId: String
    var seriesId: String
    var lastReadPercentage: Double = 0.0  // 0.0 - 1.0
    var updatedAt: Date = Date()
    var isRead: Bool = false
    var lastPageIndex: Int = 0

    init(chapterId: String, seriesId: String, lastReadPercentage: Double = 0.0, updatedAt: Date = Date(), isRead: Bool = false, lastPageIndex: Int = 0) {
        self.chapterId = chapterId
        self.seriesId = seriesId
        self.lastReadPercentage = lastReadPercentage
        self.updatedAt = updatedAt
        self.isRead = isRead
        self.lastPageIndex = lastPageIndex
    }
}
