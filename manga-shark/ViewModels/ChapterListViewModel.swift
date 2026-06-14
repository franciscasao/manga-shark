//
//  ChapterListViewModel.swift
//  manga-shark
//
//  Created by Francis Casao on 6/15/26.
//

import Combine
import Foundation

/// Drives `ChapterListView`'s state: loading a manga's chapter list from
/// Suwayomi, and downloading/extracting a tapped chapter's `.cbz` via
/// `DownloadManager` so the reader can be shown.
@MainActor
final class ChapterListViewModel: ObservableObject {
    enum State {
        case loading
        case loaded([Chapter])
        case failed(String)
    }

    /// Tracks the in-flight download/extraction triggered by tapping a chapter.
    enum DownloadState: Equatable {
        case idle
        /// `progress` is `0...1` when known, or `nil` for an indeterminate
        /// (no `Content-Length`) download.
        case downloading(Double?)
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var downloadState: DownloadState = .idle

    /// Set once a chapter has been downloaded and extracted, driving
    /// navigation to the reader via `navigationDestination(item:)`.
    @Published var readyChapter: LocalChapterData?

    let manga: Manga

    private let service: SuwayomiService
    private let downloadManager: DownloadManager

    init(manga: Manga, service: SuwayomiService = .shared, downloadManager: DownloadManager = .shared) {
        self.manga = manga
        self.service = service
        self.downloadManager = downloadManager
    }

    /// Fetches the chapter list, updating `state` for the view to render.
    ///
    /// Safe to call repeatedly (e.g. from `.task` and `.refreshable`) — each
    /// call resets to `.loading` before re-fetching. Chapters are sorted by
    /// `index` descending (latest chapter first).
    func load() async {
        state = .loading
        do {
            let chapters = try await service.fetchChapters(mangaId: manga.id)
            state = .loaded(chapters.sorted { $0.index > $1.index })
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    /// Downloads and extracts `chapter`'s `.cbz`, updating `downloadState`
    /// with progress, and sets `readyChapter` on success to trigger
    /// navigation to the reader.
    func open(_ chapter: Chapter) async {
        downloadState = .downloading(0)
        do {
            let local = try await downloadManager.prepareChapter(for: chapter) { fraction in
                Task { @MainActor in
                    self.downloadState = .downloading(fraction)
                }
            }
            downloadState = .idle
            readyChapter = local
        } catch {
            downloadState = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: Error) -> String {
        if let error = error as? SuwayomiError {
            switch error {
            case .invalidURL:
                return "The Suwayomi server address is invalid."
            case .invalidResponse:
                return "Received an unexpected response from the server."
            case .httpError(let statusCode):
                return "The server returned an error (HTTP \(statusCode))."
            case .decodingFailed:
                return "Couldn't read the chapter list from the server."
            }
        }

        if let error = error as? DownloadError {
            switch error {
            case .invalidURL:
                return "The chapter server address is invalid."
            case .invalidResponse:
                return "Received an unexpected response from the chapter server."
            case .httpError(let statusCode):
                return "The chapter server returned an error (HTTP \(statusCode))."
            case .extractionFailed:
                return "Couldn't extract the chapter archive."
            case .noPagesFound:
                return "This chapter's archive contains no pages."
            }
        }

        return error.localizedDescription
    }
}
