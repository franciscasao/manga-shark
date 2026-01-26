import SwiftUI
import Combine

struct DownloadsView: View {
    @StateObject private var viewModel = DownloadsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.queue.isEmpty {
                    ProgressView("Loading...")
                } else if viewModel.queue.isEmpty {
                    emptyView
                } else {
                    downloadsList
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: {
                            Task { await viewModel.toggleDownloader() }
                        }) {
                            Label(
                                viewModel.isDownloaderRunning ? "Pause Downloads" : "Start Downloads",
                                systemImage: viewModel.isDownloaderRunning ? "pause.circle" : "play.circle"
                            )
                        }

                        Button(role: .destructive, action: {
                            Task { await viewModel.clearQueue() }
                        }) {
                            Label("Clear Queue", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable {
                await viewModel.loadQueue()
            }
            .task {
                await viewModel.loadQueue()
            }
        }
    }

    private var emptyView: some View {
        EmptyStateView {
            Label("No Downloads", systemImage: "arrow.down.circle")
        } description: {
            Text("Downloaded chapters will appear here")
        }
    }

    private var downloadsList: some View {
        List {
            Section {
                HStack {
                    Circle()
                        .fill(viewModel.isDownloaderRunning ? .green : .orange)
                        .frame(width: 8, height: 8)

                    Text(viewModel.isDownloaderRunning ? "Downloading" : "Paused")
                        .font(.subheadline)

                    Spacer()

                    Text("\(viewModel.queue.count) in queue")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Queue") {
                ForEach(viewModel.queue) { item in
                    DownloadItemRow(item: item)
                }
                .onDelete { indexSet in
                    Task {
                        await viewModel.removeItems(at: indexSet)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct DownloadItemRow: View {
    let item: DownloadItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.mangaTitle)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(item.chapterName)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                ProgressView(value: item.progress)
                    .progressViewStyle(.linear)

                Text("\(Int(item.progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }

            HStack {
                statusBadge

                Spacer()

                if item.tries > 0 {
                    Text("Attempt \(item.tries + 1)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (text, color) = statusInfo
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .cornerRadius(4)
    }

    private var statusInfo: (String, Color) {
        switch item.state {
        case .queued:
            return ("Queued", .gray)
        case .downloading:
            return ("Downloading", .blue)
        case .finished:
            return ("Finished", .green)
        case .error:
            return ("Error", .red)
        }
    }
}

struct DownloadItem: Identifiable {
    let id: Int
    let chapterId: Int
    let chapterName: String
    let mangaId: Int
    let mangaTitle: String
    let progress: Double
    let state: DownloadState
    let tries: Int

    enum DownloadState: String {
        case queued = "QUEUED"
        case downloading = "DOWNLOADING"
        case finished = "FINISHED"
        case error = "ERROR"
    }
}

@MainActor
final class DownloadsViewModel: ObservableObject {
    @Published var queue: [DownloadItem] = []
    @Published var isLoading = false
    @Published var isDownloaderRunning = false
    @Published var errorMessage: String?

    func loadQueue() async {
        isLoading = true

        do {
            let response: GraphQLResponse<DownloadStatusResponse> = try await NetworkClient.shared.executeGraphQL(
                query: GraphQLQueries.getDownloadQueue,
                responseType: GraphQLResponse<DownloadStatusResponse>.self
            )

            if let data = response.data {
                isDownloaderRunning = data.downloadStatus.state == "STARTED"
                queue = data.downloadStatus.queue.map { item in
                    DownloadItem(
                        id: item.chapter.id,
                        chapterId: item.chapter.id,
                        chapterName: item.chapter.name,
                        mangaId: item.chapter.manga?.id ?? 0,
                        mangaTitle: item.chapter.manga?.title ?? "Unknown",
                        progress: item.progress,
                        state: DownloadItem.DownloadState(rawValue: item.state) ?? .queued,
                        tries: item.tries
                    )
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func toggleDownloader() async {
        do {
            if isDownloaderRunning {
                let _: GraphQLResponse<DownloadStatusResponse> = try await NetworkClient.shared.executeGraphQL(
                    query: GraphQLQueries.stopDownloader,
                    responseType: GraphQLResponse<DownloadStatusResponse>.self
                )
            } else {
                let _: GraphQLResponse<DownloadStatusResponse> = try await NetworkClient.shared.executeGraphQL(
                    query: GraphQLQueries.startDownloader,
                    responseType: GraphQLResponse<DownloadStatusResponse>.self
                )
            }
            await loadQueue()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearQueue() async {
        do {
            let _: GraphQLResponse<DownloadStatusResponse> = try await NetworkClient.shared.executeGraphQL(
                query: GraphQLQueries.clearDownloadQueue,
                responseType: GraphQLResponse<DownloadStatusResponse>.self
            )
            await loadQueue()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeItems(at indexSet: IndexSet) async {
        for index in indexSet {
            let item = queue[index]
            do {
                let _: GraphQLResponse<UpdateChaptersResponse> = try await NetworkClient.shared.executeGraphQL(
                    query: GraphQLQueries.deleteDownloadedChapter,
                    variables: ["chapterId": item.chapterId],
                    responseType: GraphQLResponse<UpdateChaptersResponse>.self
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        await loadQueue()
    }
}

#Preview {
    DownloadsView()
}
