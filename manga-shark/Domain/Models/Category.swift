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

// MARK: - Preview Helpers

extension Category {
    static var preview: Category {
        Category(
            id: 1,
            name: "Reading",
            order: 1,
            mangaCount: 15
        )
    }

    static var previewList: [Category] {
        [
            Category(id: 0, name: "Default", order: 0, isDefault: true, mangaCount: 25),
            Category(id: 1, name: "Reading", order: 1, mangaCount: 15),
            Category(id: 2, name: "Completed", order: 2, mangaCount: 50),
            Category(id: 3, name: "Plan to Read", order: 3, mangaCount: 30),
        ]
    }
}
