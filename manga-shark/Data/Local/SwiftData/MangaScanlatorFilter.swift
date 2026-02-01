import Foundation
import SwiftData

@Model
final class MangaScanlatorFilter {
    @Attribute(.unique) var mangaId: String
    var selectedScanlators: [String]
    var updatedAt: Date

    init(mangaId: String, selectedScanlators: [String] = [], updatedAt: Date = Date()) {
        self.mangaId = mangaId
        self.selectedScanlators = selectedScanlators
        self.updatedAt = updatedAt
    }
}
