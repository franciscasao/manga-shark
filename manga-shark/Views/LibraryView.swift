//
//  LibraryView.swift
//  manga-shark
//
//  Created by Francis Casao on 6/15/26.
//

import SwiftUI

/// The main library screen: a grid of the user's Suwayomi library covers.
struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 16)]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Library")
                .task {
                    await viewModel.load()
                }
                .navigationDestination(for: Manga.self) { manga in
                    ChapterListView(manga: manga)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Load Library", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") {
                    Task { await viewModel.load() }
                }
            }

        case .loaded(let manga):
            if manga.isEmpty {
                ContentUnavailableView(
                    "Library is Empty",
                    systemImage: "books.vertical",
                    description: Text("Add manga to your Suwayomi library to see them here.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(manga) { item in
                            NavigationLink(value: item) {
                                MangaCoverCard(manga: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    await viewModel.load()
                }
            }
        }
    }
}

#Preview {
    LibraryView()
}
