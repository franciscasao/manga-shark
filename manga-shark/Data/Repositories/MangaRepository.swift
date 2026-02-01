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

        return data.manga.chapters?.nodes?.map { $0.toDomain() } ?? []
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

    /// Legacy method for server library status - use saveToLibrary/removeFromLibrary for local-first approach
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

    // MARK: - Local Library Operations

    /// Save manga to local library with all its chapters
    @MainActor
    func saveToLibrary(mangaId: Int) async throws {
        // 1. Fetch manga and chapters from server
        let manga = try await getManga(id: mangaId, forceRefresh: true)
        let chapters = try await getChapters(mangaId: mangaId)

        // 2. Save to local storage
        try LocalLibraryRepository.shared.addToLibrary(manga: manga, chapters: chapters)

        // 3. Sync to server (fire-and-forget to not block UI)
        Task {
            try? await updateLibraryStatus(mangaId: mangaId, inLibrary: true)
        }
    }

    /// Remove manga from local library
    @MainActor
    func removeFromLibrary(mangaId: Int) async throws {
        // 1. Remove from local storage
        try LocalLibraryRepository.shared.removeFromLibrary(mangaId: mangaId)

        // 2. Sync to server (fire-and-forget to not block UI)
        Task {
            try? await updateLibraryStatus(mangaId: mangaId, inLibrary: false)
        }
    }

    /// Check if manga is in local library
    @MainActor
    func isInLocalLibrary(mangaId: Int) async -> Bool {
        return LocalLibraryRepository.shared.isInLibrary(mangaId: mangaId)
    }

    /// Refresh chapters for a manga in local library
    @MainActor
    func refreshLocalChapters(mangaId: Int) async throws {
        let remoteChapters = try await getChapters(mangaId: mangaId)
        try LocalLibraryRepository.shared.refreshChapters(mangaId: mangaId, remoteChapters: remoteChapters)
    }

    func clearCache() {
        mangaCache.removeAll()
    }

    func updateCache(_ manga: Manga) {
        mangaCache[manga.id] = manga
    }
}
