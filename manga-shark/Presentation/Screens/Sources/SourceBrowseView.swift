import SwiftUI
import Combine

struct SourceBrowseView: View {
    let source: Source
    @StateObject private var viewModel: SourceBrowseViewModel

    @State private var selectedTab: BrowseTab = .popular
    @State private var searchText = ""
    @State private var isSearching = false

    init(source: Source) {
        self.source = source
        _viewModel = StateObject(wrappedValue: SourceBrowseViewModel(source: source))
    }

    enum BrowseTab: String, CaseIterable {
        case popular
        case latest

        var title: String {
            switch self {
            case .popular: return "Popular"
            case .latest: return "Latest"
            }
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            if !isSearching {
                Picker("Browse Type", selection: $selectedTab) {
                    ForEach(BrowseTab.allCases, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
            }

            if viewModel.isLoading && viewModel.mangas.isEmpty {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            } else if viewModel.mangas.isEmpty {
                Spacer()
                EmptyStateView {
                    Label("No Manga", systemImage: "book.closed")
                } description: {
                    Text(isSearching ? "No results found" : "No manga available")
                }
                Spacer()
            } else {
                mangaGrid
            }
        }
        .navigationTitle(source.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search \(source.displayName)")
        .onSubmit(of: .search) {
            isSearching = true
            Task {
                await viewModel.search(query: searchText)
            }
        }
        .onChange(of: searchText) { newValue in
            if newValue.isEmpty {
                isSearching = false
                Task {
                    await viewModel.loadManga(type: selectedTab == .popular ? .popular : .latest)
                }
            }
        }
        .onChange(of: selectedTab) { newValue in
            Task {
                await viewModel.loadManga(type: newValue == .popular ? .popular : .latest)
            }
        }
        .task {
            await viewModel.loadManga(type: .popular)
        }
        .navigationDestination(for: Manga.self) { manga in
            MangaDetailView(mangaId: manga.id)
        }
    }

    private var mangaGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.mangas) { manga in
                    NavigationLink(value: manga) {
                        MangaGridItem(manga: manga)
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.hasNextPage {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .task {
                            await viewModel.loadNextPage()
                        }
                }
            }
            .padding()
        }
    }
}

@MainActor
final class SourceBrowseViewModel: ObservableObject {
    let source: Source

    @Published var mangas: [Manga] = []
    @Published var isLoading = false
    @Published var hasNextPage = false
    @Published var errorMessage: String?

    private var currentPage = 1
    private var currentType: SourceRepository.FetchType = .popular
    private var currentQuery: String?

    init(source: Source) {
        self.source = source
    }

    func loadManga(type: SourceRepository.FetchType) async {
        currentType = type
        currentPage = 1
        currentQuery = nil
        mangas = []

        isLoading = true
        do {
            let result = try await SourceRepository.shared.fetchManga(
                sourceId: source.id,
                type: type,
                page: currentPage
            )
            mangas = result.mangas
            hasNextPage = result.hasNextPage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func search(query: String) async {
        guard !query.isEmpty else { return }

        currentQuery = query
        currentPage = 1
        mangas = []

        isLoading = true
        do {
            let result = try await SourceRepository.shared.searchSource(
                sourceId: source.id,
                query: query,
                page: currentPage
            )
            mangas = result.mangas
            hasNextPage = result.hasNextPage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadNextPage() async {
        guard hasNextPage, !isLoading else { return }

        currentPage += 1
        isLoading = true

        do {
            let result: (mangas: [Manga], hasNextPage: Bool)
            if let query = currentQuery {
                result = try await SourceRepository.shared.searchSource(
                    sourceId: source.id,
                    query: query,
                    page: currentPage
                )
            } else {
                result = try await SourceRepository.shared.fetchManga(
                    sourceId: source.id,
                    type: currentType,
                    page: currentPage
                )
            }
            mangas.append(contentsOf: result.mangas)
            hasNextPage = result.hasNextPage
        } catch {
            errorMessage = error.localizedDescription
            currentPage -= 1
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        SourceBrowseView(source: Source(id: "1", name: "MangaDex", lang: "en"))
    }
}
