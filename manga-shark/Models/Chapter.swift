//
//  Chapter.swift
//  manga-shark
//
//  Created by Francis Casao on 6/15/26.
//

import Foundation

/// Mirrors the `ChapterDataClass` shape returned by Suwayomi's REST API
/// (e.g. `GET /api/v1/manga/{mangaId}/chapters`).
///
/// Used for metadata/listing only. The `Page` source list (`scanlator`'s
/// hosted images) is intentionally *not* modeled here — actual reading
/// content comes from the `.cbz` archive served by the Nginx file server,
/// keyed by `mangaId`/`chapterNumber` rather than this object's `url`.
struct Chapter: Codable, Identifiable, Hashable {
    /// Suwayomi's internal chapter ID.
    let id: Int

    /// Source-relative URL/path Suwayomi uses to identify this chapter.
    let url: String

    /// Display name, e.g. "Chapter 42" or a custom scanlator title.
    let name: String

    /// Upload timestamp in epoch milliseconds, as returned by Suwayomi.
    let uploadDate: Int64

    /// Numeric chapter number (may be fractional, e.g. 12.5 for an extra).
    let chapterNumber: Double

    let scanlator: String?

    /// ID of the parent `Manga`.
    let mangaId: Int

    let read: Bool
    let bookmarked: Bool

    /// Last page index the user left off on (0-based), per Suwayomi.
    let lastPageRead: Int

    /// Position of this chapter within the manga's chapter list, as
    /// reported by the source (used for ordering).
    let index: Int
}

#if DEBUG
extension Chapter {
    static let preview = Chapter(
        id: 1,
        url: "/manga/solo-leveling/chapter-1",
        name: "Chapter 1",
        uploadDate: 1_700_000_000_000,
        chapterNumber: 1,
        scanlator: "Official",
        mangaId: 1,
        read: false,
        bookmarked: false,
        lastPageRead: 0,
        index: 0
    )

    static let previewList: [Chapter] = (1...10).map { number in
        Chapter(
            id: number,
            url: "/manga/solo-leveling/chapter-\(number)",
            name: "Chapter \(number)",
            uploadDate: 1_700_000_000_000,
            chapterNumber: Double(number),
            scanlator: "Official",
            mangaId: 1,
            read: number < 3,
            bookmarked: false,
            lastPageRead: 0,
            index: number - 1
        )
    }
}
#endif
