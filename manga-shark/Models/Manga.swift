//
//  Manga.swift
//  manga-shark
//
//  Created by Francis Casao on 6/15/26.
//

import Foundation

/// Mirrors the `MangaDataClass` shape returned by Suwayomi's REST API
/// (e.g. `GET /api/v1/manga/{id}` and catalog/source browse endpoints).
///
/// Suwayomi is used strictly as a **metadata** source here: titles, covers,
/// descriptions, and chapter lists. Actual page content is never requested
/// from Suwayomi — see `DownloadManager` for the Nginx/CBZ pipeline.
struct Manga: Codable, Identifiable, Hashable {
    /// Suwayomi's internal manga ID.
    let id: Int

    /// ID of the source (extension) this manga belongs to.
    let sourceId: String

    /// Source-relative URL/path used by Suwayomi to identify this manga.
    let url: String

    let title: String
    let thumbnailUrl: String?

    let author: String?
    let artist: String?
    let description: String?
    let genre: [String]

    /// e.g. "ONGOING", "COMPLETED", "UNKNOWN" — matches Suwayomi's `MangaStatus` enum.
    let status: String?

    /// Whether this manga has been added to the user's Suwayomi library.
    let inLibrary: Bool

    /// Direct link to the manga's page on the source website, if available.
    let realUrl: String?
}

#if DEBUG
extension Manga {
    static let preview = Manga(
        id: 1,
        sourceId: "1234567890",
        url: "/manga/solo-leveling",
        title: "Solo Leveling",
        thumbnailUrl: nil,
        author: "Chugong",
        artist: "DUBU",
        description: "10 years ago, after \"the Gate\" that connected the real world with the monster world opened, some of the ordinary, everyday people received the power to hunt monsters.",
        genre: ["Action", "Adventure", "Fantasy"],
        status: "COMPLETED",
        inLibrary: true,
        realUrl: nil
    )

    static let previewList: [Manga] = [
        .preview,
        Manga(
            id: 2,
            sourceId: "1234567890",
            url: "/manga/omniscient-reader",
            title: "Omniscient Reader's Viewpoint",
            thumbnailUrl: nil,
            author: "Sing Shong",
            artist: "Sleepy-C",
            description: nil,
            genre: ["Action", "Drama"],
            status: "ONGOING",
            inLibrary: false,
            realUrl: nil
        )
    ]
}
#endif
