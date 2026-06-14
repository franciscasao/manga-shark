//
//  LibraryViewModel.swift
//  manga-shark
//
//  Created by Francis Casao on 6/15/26.
//

import Combine
import Foundation

/// Drives `LibraryView`'s state: loading the user's Suwayomi library and
/// surfacing loading/loaded/error states for the grid.
@MainActor
final class LibraryViewModel: ObservableObject {
    enum State {
        case loading
        case loaded([Manga])
        case failed(String)
    }

    @Published private(set) var state: State = .loading

    private let service: SuwayomiService

    init(service: SuwayomiService = .shared) {
        self.service = service
    }

    /// Fetches the library, updating `state` for the view to render.
    ///
    /// Safe to call repeatedly (e.g. from `.task` and `.refreshable`) — each
    /// call resets to `.loading` before re-fetching.
    func load() async {
        state = .loading
        do {
            let manga = try await service.fetchLibrary()
            state = .loaded(manga)
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: Error) -> String {
        guard let error = error as? SuwayomiError else {
            return error.localizedDescription
        }

        switch error {
        case .invalidURL:
            return "The Suwayomi server address is invalid."
        case .invalidResponse:
            return "Received an unexpected response from the server."
        case .httpError(let statusCode):
            return "The server returned an error (HTTP \(statusCode))."
        case .decodingFailed:
            return "Couldn't read the library data from the server."
        }
    }
}
