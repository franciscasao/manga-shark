import Foundation

actor SourceRepository {
    static let shared = SourceRepository()

    private var cachedSources: [Source]?

    private init() {}

    func getSources(forceRefresh: Bool = false) async throws -> [Source] {
        if !forceRefresh, let cached = cachedSources {
            return cached
        }

        let response: GraphQLResponse<SourcesResponse> = try await NetworkClient.shared.executeGraphQL(
            query: GraphQLQueries.getSources,
            responseType: GraphQLResponse<SourcesResponse>.self
        )

        guard let data = response.data else {
            if let errors = response.errors, !errors.isEmpty {
                throw RepositoryError.graphQLError(errors.first?.message ?? "Unknown error")
            }
            throw RepositoryError.noData
        }

        let sources = data.sources.nodes.map { $0.toDomain() }
        cachedSources = sources
        return sources
    }

    func getSourcesGroupedByLanguage(forceRefresh: Bool = false) async throws -> [(language: String, sources: [Source])] {
        let sources = try await getSources(forceRefresh: forceRefresh)

        let grouped = Dictionary(grouping: sources) { $0.lang }
        return grouped
            .map { (language: $0.key, sources: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.language < $1.language }
    }

    func fetchManga(sourceId: String, type: FetchType, page: Int) async throws -> (mangas: [Manga], hasNextPage: Bool) {
        let response: GraphQLResponse<FetchSourceMangaResponse> = try await NetworkClient.shared.executeGraphQL(
            query: GraphQLQueries.getSourceManga,
            variables: [
                "sourceId": sourceId,
                "type": type.rawValue,
                "page": page
            ],
            responseType: GraphQLResponse<FetchSourceMangaResponse>.self
        )

        guard let data = response.data else {
            if let errors = response.errors, !errors.isEmpty {
                throw RepositoryError.graphQLError(errors.first?.message ?? "Unknown error")
            }
            throw RepositoryError.noData
        }

        let mangas = data.fetchSourceManga.mangas.map { $0.toDomain() }
        return (mangas, data.fetchSourceManga.hasNextPage)
    }

    func searchSource(sourceId: String, query: String, page: Int) async throws -> (mangas: [Manga], hasNextPage: Bool) {
        let response: GraphQLResponse<FetchSourceMangaResponse> = try await NetworkClient.shared.executeGraphQL(
            query: GraphQLQueries.searchSource,
            variables: [
                "sourceId": sourceId,
                "query": query,
                "page": page
            ],
            responseType: GraphQLResponse<FetchSourceMangaResponse>.self
        )

        guard let data = response.data else {
            if let errors = response.errors, !errors.isEmpty {
                throw RepositoryError.graphQLError(errors.first?.message ?? "Unknown error")
            }
            throw RepositoryError.noData
        }

        let mangas = data.fetchSourceManga.mangas.map { $0.toDomain() }
        return (mangas, data.fetchSourceManga.hasNextPage)
    }

    func clearCache() {
        cachedSources = nil
    }

    enum FetchType: String {
        case popular = "POPULAR"
        case latest = "LATEST"
        case search = "SEARCH"
    }
}

enum RepositoryError: Error, LocalizedError {
    case noData
    case graphQLError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noData:
            return "No data received from server"
        case .graphQLError(let message):
            return "GraphQL error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
