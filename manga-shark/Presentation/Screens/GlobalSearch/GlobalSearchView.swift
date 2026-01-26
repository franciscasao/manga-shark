import SwiftUI
import Combine

struct GlobalSearchView: View {
    @StateObject private var viewModel = GlobalSearchViewModel()
    @State private var searchText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 12)
    ]

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Searching...")
            } else if viewModel.results.isEmpty && !searchText.isEmpty {
                SearchEmptyView(searchText: searchText)
            } else if viewModel.results.isEmpty {
                EmptyStateView {
                    Label("Global Search", systemImage: "magnifyingglass")
                } description: {
                    Text("Search across all installed sources")
                }
            } else {
                resultsList
            }
        }
        .navigationTitle("Global Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search all sources")
        .onSubmit(of: .search) {
            Task {
                await viewModel.search(query: searchText)
            }
        }
        .navigationDestination(for: Manga.self) { manga in
            MangaDetailView(mangaId: manga.id)
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(viewModel.results, id: \.source.id) { result in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if let iconUrl = result.source.iconUrl {
                                AsyncCachedImage(url: iconUrl)
                                    .frame(width: 24, height: 24)
                                    .cornerRadius(4)
                            }

                            Text(result.source.displayName)
                                .font(.headline)

                            Spacer()

                            Text("\(result.mangas.count) results")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(result.mangas) { manga in
                                    NavigationLink(value: manga) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            AsyncCachedImage(url: manga.thumbnailUrl)
                                                .aspectRatio(2/3, contentMode: .fill)
                                                .frame(width: 100, height: 150)
                                                .clipped()
                                                .cornerRadius(6)

                                            Text(manga.title)
                                                .font(.caption)
                                                .lineLimit(2)
                                                .frame(width: 100, alignment: .leading)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    if result.source.id != viewModel.results.last?.source.id {
                        Divider()
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

@MainActor
final class GlobalSearchViewModel: ObservableObject {
    @Published var results: [(source: Source, mangas: [Manga])] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func search(query: String) async {
        guard !query.isEmpty else {
            results = []
            return
        }

        isLoading = true
        results = []

        do {
            let sources = try await SourceRepository.shared.getSources()

            await withTaskGroup(of: (Source, [Manga])?.self) { group in
                for source in sources.prefix(10) {
                    group.addTask {
                        do {
                            let result = try await SourceRepository.shared.searchSource(
                                sourceId: source.id,
                                query: query,
                                page: 1
                            )
                            if !result.mangas.isEmpty {
                                return (source, result.mangas)
                            }
                        } catch {
                            // Ignore individual source errors
                        }
                        return nil
                    }
                }

                for await result in group {
                    if let result = result {
                        results.append(result)
                    }
                }
            }

            results.sort { $0.mangas.count > $1.mangas.count }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        GlobalSearchView()
    }
}
