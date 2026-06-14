//
//  DownloadManager.swift
//  manga-shark
//
//  Created by Francis Casao on 6/15/26.
//

import Foundation
import ZIPFoundation

/// Errors surfaced by `DownloadManager`.
enum DownloadError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case extractionFailed(Error)
    case noPagesFound
}

/// Handles the "storage bypass" reading pipeline:
///
/// 1. Build a direct URL into the Nginx/JuiceFS file server for a given
///    chapter's `.cbz` archive (Suwayomi is never consulted here).
/// 2. Download the archive to a local cache directory.
/// 3. Unzip it with ZIPFoundation into a per-chapter directory.
/// 4. Return the extracted page image URLs in reading order.
///
/// Also owns a simple disk cache so extracted chapters don't accumulate
/// forever on the device.
actor DownloadManager {
    static let shared = DownloadManager()

    private let session: URLSession
    private let fileManager: FileManager

    init(session: URLSession = .shared, fileManager: FileManager = .default) {
        self.session = session
        self.fileManager = fileManager
    }

    // MARK: - URL construction

    /// Builds the direct Nginx URL for a chapter's `.cbz` archive.
    ///
    /// TODO: Finalize the path convention with the Nginx/JuiceFS layout —
    /// likely something like `/{mangaId}/{chapterNumber}.cbz`. The
    /// `mangaId`/`chapterNumber` from `Chapter` should be enough to derive
    /// this once that convention is settled.
    func cbzURL(for chapter: Chapter) throws -> URL {
        let path = "/\(chapter.mangaId)/\(chapter.chapterNumber).cbz"
        guard let url = URL(string: path, relativeTo: AppConfig.cbzServerBaseURL) else {
            throw DownloadError.invalidURL
        }
        return url
    }

    // MARK: - Download

    /// Downloads the `.cbz` archive for `chapter` into the local cache
    /// directory, returning the path to the downloaded archive.
    ///
    /// TODO: Implement with `URLSession.download(from:)`, reporting
    /// progress via an `AsyncSequence` or delegate so the reader UI can
    /// show a progress indicator for large archives.
    func downloadArchive(for chapter: Chapter) async throws -> URL {
        let remoteURL = try cbzURL(for: chapter)
        let destination = archiveURL(for: chapter)

        // TODO: stream the download instead of loading the whole archive
        // into memory, and skip the request entirely if `destination`
        // already exists on disk.
        let (data, response) = try await session.data(from: remoteURL)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw DownloadError.httpError(statusCode: httpResponse.statusCode)
        }

        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destination, options: .atomic)
        return destination
    }

    // MARK: - Extraction

    /// Extracts a downloaded `.cbz` archive into a per-chapter directory
    /// and returns the page image URLs sorted in reading order.
    ///
    /// `.cbz` is just a ZIP archive of images, so this uses ZIPFoundation's
    /// `Archive` API directly.
    func extractPages(from archiveURL: URL, for chapter: Chapter) throws -> [URL] {
        let destination = extractionDirectory(for: chapter)

        // TODO: skip extraction if `destination` already contains the
        // expected page count from a previous run.
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        do {
            let archive = try Archive(url: archiveURL, accessMode: .read)
            for entry in archive {
                // Skip directory entries and non-image files (e.g. ComicInfo.xml).
                guard entry.type == .file, isImageEntry(entry.path) else { continue }

                let entryDestination = destination.appendingPathComponent(
                    (entry.path as NSString).lastPathComponent
                )
                _ = try archive.extract(entry, to: entryDestination)
            }
        } catch {
            throw DownloadError.extractionFailed(error)
        }

        let pages = try orderedPageURLs(in: destination)
        guard !pages.isEmpty else { throw DownloadError.noPagesFound }
        return pages
    }

    /// Convenience that chains `downloadArchive` and `extractPages`.
    func fetchPages(for chapter: Chapter) async throws -> [URL] {
        let archive = try await downloadArchive(for: chapter)
        return try extractPages(from: archive, for: chapter)
    }

    // MARK: - Cache management

    private var cacheRoot: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CBZCache", isDirectory: true)
    }

    private func archiveURL(for chapter: Chapter) -> URL {
        cacheRoot
            .appendingPathComponent("Archives", isDirectory: true)
            .appendingPathComponent("\(chapter.mangaId)-\(chapter.chapterNumber).cbz")
    }

    private func extractionDirectory(for chapter: Chapter) -> URL {
        cacheRoot
            .appendingPathComponent("Pages", isDirectory: true)
            .appendingPathComponent("\(chapter.mangaId)-\(chapter.chapterNumber)", isDirectory: true)
    }

    private func isImageEntry(_ path: String) -> Bool {
        let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "webp", "gif", "heic"]
        return imageExtensions.contains((path as NSString).pathExtension.lowercased())
    }

    private func orderedPageURLs(in directory: URL) throws -> [URL] {
        try fileManager
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { isImageEntry($0.lastPathComponent) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Evicts cached archives/extracted pages until the total cache size
    /// is under `maxBytes`, oldest-accessed first.
    ///
    /// TODO: Implement LRU eviction based on file access dates. Should be
    /// invoked periodically (e.g. on app launch or background refresh) so
    /// the device doesn't fill up with extracted manhwa pages indefinitely.
    func pruneCache(maxBytes: Int64) async throws {
        // Intentionally unimplemented for now.
    }
}
