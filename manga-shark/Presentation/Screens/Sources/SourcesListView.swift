import SwiftUI
import Combine

struct SourcesListView: View {
    @StateObject private var viewModel = SourcesListViewModel()
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.groupedSources.isEmpty {
                    ProgressView("Loading sources...")
                } else if viewModel.groupedSources.isEmpty {
                    EmptyStateView {
                        Label("No Sources", systemImage: "globe")
                    } description: {
                        Text("No sources are installed on the server.")
                    }
                } else {
                    sourcesList
                }
            }
            .navigationTitle("Browse")
            .searchable(text: $searchText, prompt: "Search sources")
            .refreshable {
                await viewModel.loadSources(forceRefresh: true)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: "globalSearch") {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "globalSearch" {
                    GlobalSearchView()
                }
            }
            .navigationDestination(for: Source.self) { source in
                SourceBrowseView(source: source)
            }
            .task {
                await viewModel.loadSources()
            }
        }
    }

    private var sourcesList: some View {
        List {
            ForEach(viewModel.filteredSources(searchText: searchText), id: \.language) { group in
                Section(group.displayLanguage) {
                    ForEach(group.sources) { source in
                        NavigationLink(value: source) {
                            SourceRowView(source: source)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct SourceRowView: View {
    let source: Source

    var body: some View {
        HStack(spacing: 12) {
            AsyncCachedImage(url: source.iconUrl)
                .frame(width: 40, height: 40)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(source.displayName)
                        .font(.body)

                    if source.isNsfw {
                        Text("18+")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.red)
                            .foregroundStyle(.white)
                            .cornerRadius(4)
                    }
                }

                Text(source.languageDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

@MainActor
final class SourcesListViewModel: ObservableObject {
    @Published var groupedSources: [(language: String, displayLanguage: String, sources: [Source])] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadSources(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil

        do {
            let grouped = try await SourceRepository.shared.getSourcesGroupedByLanguage(forceRefresh: forceRefresh)
            let locale = Locale.current
            groupedSources = grouped.map { group in
                let displayLanguage = locale.localizedString(forLanguageCode: group.language) ?? group.language.uppercased()
                return (language: group.language, displayLanguage: displayLanguage, sources: group.sources)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func filteredSources(searchText: String) -> [(language: String, displayLanguage: String, sources: [Source])] {
        if searchText.isEmpty {
            return groupedSources
        }

        return groupedSources.compactMap { group in
            let filtered = group.sources.filter { source in
                source.name.localizedCaseInsensitiveContains(searchText) ||
                source.displayName.localizedCaseInsensitiveContains(searchText)
            }
            if filtered.isEmpty {
                return nil
            }
            return (language: group.language, displayLanguage: group.displayLanguage, sources: filtered)
        }
    }
}

#Preview {
    SourcesListView()
}
