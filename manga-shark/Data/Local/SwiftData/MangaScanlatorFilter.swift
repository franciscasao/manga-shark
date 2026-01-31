import Foundation
import SwiftData

@available(iOS 17, *)
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
