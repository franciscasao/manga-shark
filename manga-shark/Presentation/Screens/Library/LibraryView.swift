import SwiftUI
import Combine

struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var searchText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.library.isEmpty {
                    ProgressView("Loading library...")
                } else if viewModel.library.isEmpty {
                    emptyLibraryView
                } else {
                    libraryGrid
                }
            }
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search library")
            .refreshable {
                await viewModel.loadLibrary(forceRefresh: true)
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

                        Divider()

                        Button(action: { Task { await viewModel.loadLibrary(forceRefresh: true) } }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .task {
                await viewModel.loadLibrary()
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

    private var libraryGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.filteredLibrary(searchText: searchText)) { manga in
                    NavigationLink(value: manga) {
                        MangaGridItem(manga: manga)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationDestination(for: Manga.self) { manga in
            MangaDetailView(mangaId: manga.id)
        }
    }
}

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var library: [Manga] = []
    @Published var categories: [Category] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var sortOrder: SortOrder = .title {
        didSet { sortLibrary() }
    }
    @Published var sortAscending: Bool = true {
        didSet { sortLibrary() }
    }

    enum SortOrder: String, CaseIterable {
        case title
        case unreadCount
        case lastRead
        case dateAdded

        var displayName: String {
            switch self {
            case .title: return "Title"
            case .unreadCount: return "Unread Count"
            case .lastRead: return "Last Read"
            case .dateAdded: return "Date Added"
            }
        }
    }

    func loadLibrary(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil

        do {
            library = try await LibraryRepository.shared.getLibrary(forceRefresh: forceRefresh)
            categories = try await LibraryRepository.shared.getCategories(forceRefresh: forceRefresh)
            sortLibrary()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func filteredLibrary(searchText: String) -> [Manga] {
        if searchText.isEmpty {
            return library
        }
        return library.filter { manga in
            manga.title.localizedCaseInsensitiveContains(searchText) ||
            (manga.author?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (manga.artist?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private func sortLibrary() {
        library.sort { a, b in
            let result: Bool
            switch sortOrder {
            case .title:
                result = a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            case .unreadCount:
                result = a.unreadCount < b.unreadCount
            case .lastRead:
                let aDate = a.lastReadChapter?.fetchedAt ?? .distantPast
                let bDate = b.lastReadChapter?.fetchedAt ?? .distantPast
                result = aDate < bDate
            case .dateAdded:
                let aDate = a.inLibraryAt ?? .distantPast
                let bDate = b.inLibraryAt ?? .distantPast
                result = aDate < bDate
            }
            return sortAscending ? result : !result
        }
    }
}

#Preview {
    LibraryView()
}
