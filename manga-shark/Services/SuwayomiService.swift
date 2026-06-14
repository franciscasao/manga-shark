//
//  SuwayomiService.swift
//  manga-shark
//
//  Created by Francis Casao on 6/15/26.
//

import Foundation

/// Errors surfaced by `SuwayomiService`.
enum SuwayomiError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingFailed(Error)
}

/// Thin REST client for a self-hosted Suwayomi instance.
///
/// Responsibility is **strictly metadata**: browsing sources, fetching
/// manga details, and listing chapters. This service must never be used
/// to fetch chapter page images — Suwayomi can drop deleted chapters from
/// its database, so reading content is served separately by an Nginx file
/// server as `.cbz` archives (see `DownloadManager`).
///
/// Modeled as an `actor` so concurrent callers share one `URLSession`
/// safely, mirroring the concurrency approach used elsewhere in the app.
actor SuwayomiService {
    static let shared = SuwayomiService()

    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder

    init(baseURL: URL = AppConfig.suwayomiBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
    }

    // MARK: - Catalog

    /// Fetches the list of installed/enabled sources.
    ///
    /// Maps to `GET /api/v1/source/list`.
    func fetchSources() async throws -> [Source] {
        // TODO: Define a `Source` model (id, name, lang, iconUrl, supportsLatest)
        // and decode the response array below.
        try await request(path: "/source/list")
    }

    /// Fetches a page of popular manga for a given source.
    ///
    /// Maps to `GET /api/v1/source/{sourceId}/popular/{page}`.
    func fetchPopularManga(sourceId: String, page: Int) async throws -> [Manga] {
        // TODO: Suwayomi wraps results in a `MangaPage` envelope
        // (`{ "mangaList": [...], "hasNextPage": bool }`) — decode that
        // wrapper type and return `mangaList` once implemented.
        try await request(path: "/source/\(sourceId)/popular/\(page)")
    }

    /// Searches a source's catalog.
    ///
    /// Maps to `GET /api/v1/source/{sourceId}/search/{page}?searchTerm={query}`.
    func searchManga(sourceId: String, query: String, page: Int) async throws -> [Manga] {
        // TODO: Same `MangaPage` envelope as `fetchPopularManga`.
        try await request(
            path: "/source/\(sourceId)/search/\(page)",
            queryItems: [URLQueryItem(name: "searchTerm", value: query)]
        )
    }

    // MARK: - Manga details

    /// Fetches full details for a single manga.
    ///
    /// Maps to `GET /api/v1/manga/{mangaId}/full`.
    func fetchMangaDetails(mangaId: Int) async throws -> Manga {
        try await request(path: "/manga/\(mangaId)/full")
    }

    /// Fetches the chapter list for a manga.
    ///
    /// Maps to `GET /api/v1/manga/{mangaId}/chapters`.
    func fetchChapters(mangaId: Int) async throws -> [Chapter] {
        try await request(path: "/manga/\(mangaId)/chapters")
    }

    // MARK: - Networking core

    /// Issues a `GET` request to `{baseURL}/api/v1{path}` and decodes the
    /// JSON response as `T`.
    private func request<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(AppConfig.apiVersionPath + path),
            resolvingAgainstBaseURL: false
        ) else {
            throw SuwayomiError.invalidURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw SuwayomiError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SuwayomiError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw SuwayomiError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw SuwayomiError.decodingFailed(error)
        }
    }
}
