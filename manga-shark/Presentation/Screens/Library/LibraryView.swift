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
            .alert("Error Loading Library", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
                Button("Retry") {
                    Task {
                        await viewModel.loadLibrary(forceRefresh: true)
                    }
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
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
                        MangaGridItem(
                            manga: manga,
                            deviceUnreadCount: viewModel.deviceUnreadCounts[manga.id]
                        )
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
    @Published var deviceUnreadCounts: [Int: Int] = [:] // manga ID -> device-specific unread count

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
        print("🎬 [LibraryViewModel] Starting library load")
        isLoading = true
        errorMessage = nil

        do {
            print("🎬 [LibraryViewModel] Fetching library...")
            library = try await LibraryRepository.shared.getLibrary(forceRefresh: forceRefresh)
            print("✅ [LibraryViewModel] Library loaded successfully: \(library.count) items")

            print("🎬 [LibraryViewModel] Fetching categories...")
            categories = try await LibraryRepository.shared.getCategories(forceRefresh: forceRefresh)
            print("✅ [LibraryViewModel] Categories loaded successfully: \(categories.count) items")

            sortLibrary()
            print("✅ [LibraryViewModel] Library sorted")

            // Calculate device-specific unread counts in the background
            Task {
                await calculateDeviceUnreadCounts()
            }
        } catch {
            print("❌ [LibraryViewModel] Error loading library: \(error)")
            print("❌ [LibraryViewModel] Error type: \(type(of: error))")
            print("❌ [LibraryViewModel] Error details: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ [LibraryViewModel] NSError domain: \(nsError.domain)")
                print("❌ [LibraryViewModel] NSError code: \(nsError.code)")
                print("❌ [LibraryViewModel] NSError userInfo: \(nsError.userInfo)")
            }
            errorMessage = error.localizedDescription
        }

        isLoading = false
        print("🎬 [LibraryViewModel] Library load completed (hasError: \(errorMessage != nil))")
    }

    func calculateDeviceUnreadCounts() async {
        let deviceId = DeviceIdentifierManager.shared.deviceId
        print("📊 [LibraryViewModel] Calculating device-specific unread counts for \(library.count) manga")

        for manga in library {
            do {
                // Fetch chapters for this manga
                let chapters = try await MangaRepository.shared.getChapters(mangaId: manga.id)

                // Calculate device-specific unread count
                let unreadCount = try await CoreDataStack.shared.getDeviceUnreadCount(chapters: chapters, deviceId: deviceId)

                // Update the dictionary
                deviceUnreadCounts[manga.id] = unreadCount
                print("✅ [LibraryViewModel] Manga '\(manga.title)' - Device unread: \(unreadCount), Server unread: \(manga.unreadCount)")
            } catch {
                print("❌ [LibraryViewModel] Failed to calculate unread count for manga \(manga.id): \(error)")
                // Keep server unread count on error
            }
        }

        print("✅ [LibraryViewModel] Device-specific unread counts calculated")
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
                // Use device-specific unread count if available, otherwise use server count
                let aUnread = deviceUnreadCounts[a.id] ?? a.unreadCount
                let bUnread = deviceUnreadCounts[b.id] ?? b.unreadCount
                result = aUnread < bUnread
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
