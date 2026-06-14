//
//  LibraryCategory.swift
//  manga-shark
//
//  Created by Francis Casao on 6/15/26.
//

import Foundation

/// Mirrors the `CategoryDataClass` shape returned by Suwayomi's REST API
/// (`GET /api/v1/category`). Represents a user-defined library category
/// (e.g. "Default", "Webtoons.com") whose manga can be listed via
/// `GET /api/v1/category/{id}`.
///
/// Suwayomi has no single "whole library" endpoint — the library is the
/// union of every category's manga, so `SuwayomiService.fetchLibrary()`
/// fetches this list first to know which categories to fan out to.
///
/// Named `LibraryCategory` (rather than `Category`) to avoid colliding with
/// platform type aliases named `Category`.
struct LibraryCategory: Codable, Identifiable, Hashable {
    let id: Int
    let order: Int
    let name: String

    /// Whether this is Suwayomi's built-in "Default" category.
    let isDefault: Bool

    private enum CodingKeys: String, CodingKey {
        case id, order, name
        case isDefault = "default"
    }
}

#if DEBUG
extension LibraryCategory {
    static let preview = LibraryCategory(id: 0, order: 0, name: "Default", isDefault: true)

    static let previewList: [LibraryCategory] = [
        .preview,
        LibraryCategory(id: 1, order: 1, name: "Webtoons.com", isDefault: false)
    ]
}
#endif
