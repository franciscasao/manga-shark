//
//  AppConfig.swift
//  manga-shark
//
//  Created by Francis Casao on 6/15/26.
//

import Foundation

/// Central place for the two server endpoints this app talks to.
///
/// - `suwayomiBaseURL`: self-hosted Suwayomi instance, used **only** for
///   catalog/metadata REST calls (sources, manga details, chapter lists).
/// - `cbzServerBaseURL`: Nginx file server in front of the JuiceFS/S3
///   backend that actually hosts the `.cbz` chapter archives. Reading
///   content is fetched from here directly, bypassing Suwayomi entirely,
///   since Suwayomi is prone to dropping deleted chapters from its DB.
///
/// TODO: Replace these placeholder values with values read from a
/// user-configurable settings screen (and/or `UserDefaults`/Keychain),
/// the same way the previous implementation had a `ServerSetupView`.
enum AppConfig {
    /// Base URL for Suwayomi's REST API, e.g. `http://suwayomi.local:4567`.
    static var suwayomiBaseURL: URL {
        URL(string: "http://franciss-mac-mini.wampus-boa.ts.net:4567")!
    }

    /// Base URL for the Nginx server hosting raw `.cbz` chapter archives,
    /// e.g. `http://files.local`.
    static var cbzServerBaseURL: URL {
        URL(string: "http://files.local")!
    }

    /// Suwayomi REST API version path prefix.
    static let apiVersionPath = "/api/v1"

    /// Resolves a server-relative path returned by Suwayomi (e.g.
    /// `/api/v1/manga/677/thumbnail`) into an absolute URL against
    /// `suwayomiBaseURL`.
    ///
    /// Unlike `apiVersionPath`-based requests in `SuwayomiService`, these
    /// paths already include `/api/v1`, so this resolves against the host
    /// root rather than appending `apiVersionPath` again.
    static func absoluteURL(for serverPath: String) -> URL? {
        guard !serverPath.isEmpty else { return nil }
        return URL(string: serverPath, relativeTo: suwayomiBaseURL)?.absoluteURL
    }
}
