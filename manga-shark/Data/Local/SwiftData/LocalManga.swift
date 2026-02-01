import Foundation
import SwiftData

@Model
final class LocalManga {
    @Attribute(.unique) var serverId: Int
    var sourceId: String
    var url: String
    var title: String
    var thumbnailUrl: String?
    var artist: String?
    var author: String?
    var descriptionText: String?
    var genres: [String]
    var status: String  // MangaStatus raw value
    var addedToLibraryAt: Date
    var lastRefreshedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \LocalChapter.manga)
    var chapters: [LocalChapter] = []

    init(
        serverId: Int,
        sourceId: String,
        url: String,
        title: String,
        thumbnailUrl: String? = nil,
        artist: String? = nil,
        author: String? = nil,
        descriptionText: String? = nil,
        genres: [String] = [],
        status: String = "UNKNOWN",
        addedToLibraryAt: Date = Date(),
        lastRefreshedAt: Date? = nil
    ) {
        self.serverId = serverId
        self.sourceId = sourceId
        self.url = url
        self.title = title
        self.thumbnailUrl = thumbnailUrl
        self.artist = artist
        self.author = author
        self.descriptionText = descriptionText
        self.genres = genres
        self.status = status
        self.addedToLibraryAt = addedToLibraryAt
        self.lastRefreshedAt = lastRefreshedAt
    }
}
