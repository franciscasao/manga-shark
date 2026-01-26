import Foundation

actor MangaRepository {
    static let shared = MangaRepository()

    private var mangaCache: [Int: Manga] = [:]

    private init() {}

    func getManga(id: Int, forceRefresh: Bool = false) async throws -> Manga {
        if !forceRefresh, let cached = mangaCache[id] {
            return cached
        }

        let response: GraphQLResponse<MangaResponse> = try await NetworkClient.shared.executeGraphQL(
            query: GraphQLQueries.getManga,
            variables: ["id": id],
            responseType: GraphQLResponse<MangaResponse>.self
        )

        guard let data = response.data else {
            if let errors = response.errors, !errors.isEmpty {
                throw RepositoryError.graphQLError(errors.first?.message ?? "Unknown error")
            }
            throw RepositoryError.noData
        }

        let manga = data.manga.toDomain()
        mangaCache[id] = manga
        return manga
    }

    func getChapters(mangaId: Int) async throws -> [Chapter] {
        let response: GraphQLResponse<MangaResponse> = try await NetworkClient.shared.executeGraphQL(
            query: GraphQLQueries.getManga,
            variables: ["id": mangaId],
            responseType: GraphQLResponse<MangaResponse>.self
        )

        guard let data = response.data else {
            if let errors = response.errors, !errors.isEmpty {
                throw RepositoryError.graphQLError(errors.first?.message ?? "Unknown error")
            }
            throw RepositoryError.noData
        }

        return data.manga.chapters?.nodes.map { $0.toDomain() } ?? []
    }

    func fetchChapters(mangaId: Int) async throws -> [Chapter] {
        let response: GraphQLResponse<FetchChaptersResponse> = try await NetworkClient.shared.executeGraphQL(
            query: GraphQLQueries.fetchChapters,
            variables: ["mangaId": mangaId],
            responseType: GraphQLResponse<FetchChaptersResponse>.self
        )

        guard let data = response.data else {
            if let errors = response.errors, !errors.isEmpty {
                throw RepositoryError.graphQLError(errors.first?.message ?? "Unknown error")
            }
            throw RepositoryError.noData
        }

        return data.fetchChapters.chapters.map { $0.toDomain() }
    }

    func updateLibraryStatus(mangaId: Int, inLibrary: Bool) async throws -> Manga {
        let response: GraphQLResponse<UpdateMangaResponse> = try await NetworkClient.shared.executeGraphQL(
            query: GraphQLQueries.updateMangaLibrary,
            variables: [
                "id": mangaId,
                "inLibrary": inLibrary
            ],
            responseType: GraphQLResponse<UpdateMangaResponse>.self
        )

        guard let data = response.data else {
            if let errors = response.errors, !errors.isEmpty {
                throw RepositoryError.graphQLError(errors.first?.message ?? "Unknown error")
            }
            throw RepositoryError.noData
        }

        let manga = data.updateManga.manga.toDomain()
        mangaCache[mangaId] = manga
        return manga
    }

    func clearCache() {
        mangaCache.removeAll()
    }

    func updateCache(_ manga: Manga) {
        mangaCache[manga.id] = manga
    }
}
