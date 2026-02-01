import SwiftUI
import SwiftData
import Combine

struct LibraryView: View {
    @Query(sort: \LocalManga.title) private var localMangaList: [LocalManga]
    @StateObject private var viewModel = LibraryViewModel()
    @State private var searchText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && localMangaList.isEmpty {
                    ProgressView("Loading library...")
                } else if localMangaList.isEmpty {
                    emptyLibraryView
                } else {
                    libraryGrid
                }
            }
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search library")
            .refreshable {
                await viewModel.refreshUnreadCounts(for: localMangaList)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort by", selection: $viewModel.sortOrder) {
                            ForEach(LibraryViewModel.SortOrder.allCases, id: \.self) { order in
                                Text(order.displayName).tag(order)
                            }
                        }

                        Toggle("Ascending", isOn: $viewModel.sortAscending)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .task {
                await viewModel.refreshUnreadCounts(for: localMangaList)
            }
            .onChange(of: localMangaList.count) { _, _ in
                Task {
                    await viewModel.refreshUnreadCounts(for: localMangaList)
                }
            }
        }
    }

    private var emptyLibraryView: some View {
        EmptyStateView {
            Label("No Manga", systemImage: "books.vertical")
        } description: {
            Text("Your library is empty. Browse sources to add manga.")
        }
    }

    private var filteredManga: [LocalManga] {
        let filtered: [LocalManga]
        if searchText.isEmpty {
            filtered = localMangaList
        } else {
            filtered = localMangaList.filter { manga in
                manga.title.localizedCaseInsensitiveContains(searchText) ||
                (manga.author?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (manga.artist?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return viewModel.sortManga(Array(filtered))
    }

    private var libraryGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredManga, id: \.serverId) { manga in
                    NavigationLink(value: manga.serverId) {
                        LocalMangaGridItem(
                            manga: manga,
                            deviceUnreadCount: viewModel.deviceUnreadCounts[manga.serverId] ?? 0
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationDestination(for: Int.self) { mangaId in
            MangaDetailView(mangaId: mangaId)
        }
    }
}

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var deviceUnreadCounts: [Int: Int] = [:] // manga serverId -> device-specific unread count

    @Published var sortOrder: SortOrder = .title
    @Published var sortAscending: Bool = true

    enum SortOrder: String, CaseIterable {
        case title
        case unreadCount
        case dateAdded

        var displayName: String {
            switch self {
            case .title: return "Title"
            case .unreadCount: return "Unread Count"
            case .dateAdded: return "Date Added"
            }
        }
    }

    func refreshUnreadCounts(for mangaList: [LocalManga]) async {
        guard !mangaList.isEmpty else { return }

        print("📊 [LibraryViewModel] Calculating device-specific unread counts for \(mangaList.count) local manga")
        isLoading = true

        // Load all scanlator filters once at start
        let allFilters = await ScanlatorFilterManager.shared.getAllFilters()

        for manga in mangaList {
            let localChapters = manga.chapters
            let mangaIdStr = String(manga.serverId)

            // Apply scanlator filter if exists for this manga
            let filter = allFilters[mangaIdStr] ?? Set()
            let filteredChapters: [LocalChapter]
            if filter.isEmpty {
                filteredChapters = localChapters
            } else {
                filteredChapters = localChapters.filter { chapter in
                    guard let scanlator = chapter.scanlator, !scanlator.isEmpty else {
                        return false
                    }
                    return filter.contains(scanlator)
                }
            }

            let chapterIds = filteredChapters.map { $0.serverId }

            // Use ReadingProgressManager which reads from correct source per iOS version
            let readStatus = await ReadingProgressManager.shared.getReadStatus(for: chapterIds)

            // Calculate unread count: chapters not marked as read
            var unreadCount = 0
            for chapter in filteredChapters {
                let isRead = readStatus[chapter.serverId] ?? false
                if !isRead {
                    unreadCount += 1
                }
            }

            // Update the dictionary
            deviceUnreadCounts[manga.serverId] = unreadCount
            print("✅ [LibraryViewModel] Local manga '\(manga.title)' - Device unread: \(unreadCount), Filter: \(filter.isEmpty ? "none" : "\(filter.count) scanlators")")
        }

        isLoading = false
        print("✅ [LibraryViewModel] Device-specific unread counts calculated")
    }

    func sortManga(_ manga: [LocalManga]) -> [LocalManga] {
        manga.sorted { a, b in
            let result: Bool
            switch sortOrder {
            case .title:
                result = a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            case .unreadCount:
                let aUnread = deviceUnreadCounts[a.serverId] ?? 0
                let bUnread = deviceUnreadCounts[b.serverId] ?? 0
                result = aUnread < bUnread
            case .dateAdded:
                result = a.addedToLibraryAt < b.addedToLibraryAt
            }
            return sortAscending ? result : !result
        }
    }
}

#Preview("Library Grid") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: LocalManga.self, LocalChapter.self, ChapterProgress.self, MangaScanlatorFilter.self,
        configurations: config
    )

    // Add preview data
    let context = container.mainContext
    for i in 1...5 {
        let manga = LocalManga(
            serverId: i,
            sourceId: "preview",
            url: "/manga/\(i)",
            title: "Preview Manga \(i)",
            genres: ["Action", "Adventure"],
            status: "ONGOING"
        )
        context.insert(manga)
    }

    return LibraryView()
        .modelContainer(container)
}

#Preview("Empty Library") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: LocalManga.self, LocalChapter.self, ChapterProgress.self, MangaScanlatorFilter.self,
        configurations: config
    )

    return LibraryView()
        .modelContainer(container)
}
