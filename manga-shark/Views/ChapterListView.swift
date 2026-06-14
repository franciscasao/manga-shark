//
//  ChapterListView.swift
//  manga-shark
//
//  Created by Francis Casao on 6/15/26.
//

import SwiftUI

/// Lists a manga's chapters. Tapping a chapter downloads and extracts its
/// `.cbz` via `DownloadManager` (showing a progress indicator), then
/// navigates to the reader.
struct ChapterListView: View {
    @StateObject private var viewModel: ChapterListViewModel

    init(manga: Manga) {
        _viewModel = StateObject(wrappedValue: ChapterListViewModel(manga: manga))
    }

    var body: some View {
        content
            .navigationTitle(viewModel.manga.title)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.load()
            }
            .navigationDestination(item: $viewModel.readyChapter) { localChapter in
                ReaderView(localChapter: localChapter)
            }
            .overlay {
                downloadOverlay
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
                Label("Couldn't Load Chapters", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") {
                    Task { await viewModel.load() }
                }
            }

        case .loaded(let chapters):
            if chapters.isEmpty {
                ContentUnavailableView(
                    "No Chapters",
                    systemImage: "book.closed",
                    description: Text("This manga has no chapters available yet.")
                )
            } else {
                List(chapters) { chapter in
                    Button {
                        Task { await viewModel.open(chapter) }
                    } label: {
                        chapterRow(chapter)
                    }
                    .disabled(isDownloading)
                }
                .refreshable {
                    await viewModel.load()
                }
            }
        }
    }

    private func chapterRow(_ chapter: Chapter) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.name)
                    .foregroundStyle(chapter.read ? .secondary : .primary)
                if let scanlator = chapter.scanlator, !scanlator.isEmpty {
                    Text(scanlator)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if chapter.read {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private var isDownloading: Bool {
        if case .downloading = viewModel.downloadState { return true }
        return false
    }

    @ViewBuilder
    private var downloadOverlay: some View {
        switch viewModel.downloadState {
        case .idle:
            EmptyView()

        case .downloading(let fraction):
            ZStack {
                Color.black.opacity(0.25)
                VStack(spacing: 12) {
                    if let fraction {
                        ProgressView(value: fraction)
                            .frame(width: 160)
                    } else {
                        ProgressView()
                    }
                    Text("Downloading chapter…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .ignoresSafeArea()

        case .failed(let message):
            ContentUnavailableView {
                Label("Download Failed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            }
            .background(.regularMaterial)
        }
    }
}

#Preview {
    NavigationStack {
        ChapterListView(manga: .preview)
    }
}
