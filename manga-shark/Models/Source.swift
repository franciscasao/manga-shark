//
//  Source.swift
//  manga-shark
//
//  Created by Francis Casao on 6/15/26.
//

import Foundation

/// Mirrors the `SourceDataClass` shape returned by Suwayomi's REST API
/// (`GET /api/v1/source/list`). Represents an installed extension/source
/// (e.g. a specific scanlation site) that can be browsed or searched.
struct Source: Codable, Identifiable, Hashable {
    /// Suwayomi's internal source ID. Sent as a string in JSON because it
    /// can exceed 32-bit integer range.
    let id: String

    let name: String
    let lang: String
    let iconUrl: String?
    let supportsLatest: Bool
}

#if DEBUG
extension Source {
    static let preview = Source(
        id: "1234567890",
        name: "Example Source",
        lang: "en",
        iconUrl: nil,
        supportsLatest: true
    )
}
#endif
