import Foundation

struct Category: Identifiable, Hashable {
    let id: Int
    let name: String
    let order: Int
    let includeInUpdate: IncludeInUpdate
    let includeInDownload: IncludeInUpdate
    let isDefault: Bool
    let mangaCount: Int

    init(
        id: Int,
        name: String,
        order: Int = 0,
        includeInUpdate: IncludeInUpdate = .unset,
        includeInDownload: IncludeInUpdate = .unset,
        isDefault: Bool = false,
        mangaCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.order = order
        self.includeInUpdate = includeInUpdate
        self.includeInDownload = includeInDownload
        self.isDefault = isDefault
        self.mangaCount = mangaCount
    }

    enum IncludeInUpdate: String {
        case unset = "UNSET"
        case include = "INCLUDE"
        case exclude = "EXCLUDE"
    }
}

extension Category {
    static let defaultCategory = Category(
        id: 0,
        name: "Default",
        order: 0,
        isDefault: true
    )
}
