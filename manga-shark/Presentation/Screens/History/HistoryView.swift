import SwiftUI
import SwiftData

// MARK: - History View

struct HistoryView: View {
    @Query(sort: \ReadingHistory.lastReadDate, order: .reverse)
    private var historyEntries: [ReadingHistory]

    @State private var showingClearConfirmation = false
    @State private var selectedEntry: ReadingHistory?

    var body: some View {
        NavigationStack {
            Group {
                if historyEntries.isEmpty {
                    emptyView
                } else {
                    historyList
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !historyEntries.isEmpty {
                        Button(action: { showingClearConfirmation = true }) {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .confirmationDialog(
                "Clear Reading History",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    Task {
                        await HistoryManager.shared.clearAllHistory()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all reading history. This action cannot be undone.")
            }
            .navigationDestination(item: $selectedEntry) { entry in
                HistoryReaderDestination(
                    mangaId: Int(entry.mangaId) ?? 0,
                    chapterId: Int(entry.chapterId) ?? 0,
                    mangaTitle: entry.seriesName,
                    thumbnailUrl: entry.thumbnailUrl
                )
            }
        }
    }

    private var emptyView: some View {
        EmptyStateView {
            Label("No History", systemImage: "clock.arrow.circlepath")
        } description: {
            Text("Manga you read will appear here")
        }
    }

    private var historyList: some View {
        List {
            ForEach(historyEntries) { entry in
                Button {
                    selectedEntry = entry
                } label: {
                    HistoryRowView(
                        seriesName: entry.seriesName,
                        chapterName: entry.chapterName,
                        chapterNumber: entry.chapterNumber,
                        thumbnailUrl: entry.thumbnailUrl,
                        lastReadDate: entry.lastReadDate,
                        progressPercentage: entry.progressPercentage
                    )
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                Task {
                    for index in indexSet {
                        let entry = historyEntries[index]
                        await HistoryManager.shared.deleteEntry(mangaId: entry.mangaId)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Reader Destination Helper

struct HistoryReaderDestination: View {
    let mangaId: Int
    let chapterId: Int
    let mangaTitle: String
    let thumbnailUrl: String?

    @State private var chapters: [Chapter] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading chapter...")
            } else if let chapter = chapters.first(where: { $0.id == chapterId }) {
                ReaderView(
                    chapter: chapter,
                    chapters: chapters,
                    mangaTitle: mangaTitle,
                    mangaThumbnailUrl: thumbnailUrl
                )
            } else if let errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Failed to load chapter")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await loadChapters()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.questionmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Chapter not found")
                        .font(.headline)
                    Text("The chapter may have been removed or is no longer available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .task {
            await loadChapters()
        }
    }

    private func loadChapters() async {
        isLoading = true
        errorMessage = nil
        do {
            chapters = try await MangaRepository.shared.getChapters(mangaId: mangaId)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Shared Row Component

struct HistoryRowView: View {
    let seriesName: String
    let chapterName: String
    let chapterNumber: Double
    let thumbnailUrl: String?
    let lastReadDate: Date
    let progressPercentage: Double

    var body: some View {
        HStack(spacing: 12) {
            AsyncCachedImage(url: thumbnailUrl)
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 50, height: 75)
                .clipped()
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 4) {
                Text(seriesName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text(chapterDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    if progressPercentage > 0 && progressPercentage < 1.0 {
                        ProgressView(value: progressPercentage)
                            .progressViewStyle(.linear)
                            .frame(width: 60)

                        Text("\(Int(progressPercentage * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if progressPercentage >= 1.0 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text("Completed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(lastReadDate.relativeString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var chapterDisplayName: String {
        let chapterNum = Int(chapterNumber)
        if !chapterName.isEmpty && chapterName != "Chapter \(chapterNum)" {
            return "Ch. \(chapterNum) - \(chapterName)"
        }
        return "Chapter \(chapterNum)"
    }
}

#Preview("History View") {
    HistoryView()
}

#Preview("History Row - In Progress") {
    HistoryRowView(
        seriesName: "One Piece",
        chapterName: "Romance Dawn",
        chapterNumber: 1.0,
        thumbnailUrl: nil,
        lastReadDate: Date(),
        progressPercentage: 0.75
    )
    .padding()
}

#Preview("History Row - Completed") {
    HistoryRowView(
        seriesName: "Naruto",
        chapterName: "Uzumaki Naruto",
        chapterNumber: 1.0,
        thumbnailUrl: nil,
        lastReadDate: Date().addingTimeInterval(-3600),
        progressPercentage: 1.0
    )
    .padding()
}

#Preview("With Sample Data") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ReadingHistory.self, configurations: config)

    for entry in ReadingHistory.previewList {
        container.mainContext.insert(entry)
    }

    return HistoryView()
        .modelContainer(container)
}
