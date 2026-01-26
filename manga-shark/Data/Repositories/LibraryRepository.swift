import Foundation

actor LibraryRepository {
    static let shared = LibraryRepository()

    private var cachedLibrary: [Manga]?
    private var cachedCategories: [Category]?

    private init() {}

    func getLibrary(forceRefresh: Bool = false) async throws -> [Manga] {
        if !forceRefresh, let cached = cachedLibrary {
            return cached
        }

        let response: GraphQLResponse<LibraryResponse> = try await NetworkClient.shared.executeGraphQL(
            query: GraphQLQueries.getLibrary,
            responseType: GraphQLResponse<LibraryResponse>.self
        )

        guard let data = response.data else {
            if let errors = response.errors, !errors.isEmpty {
                throw RepositoryError.graphQLError(errors.first?.message ?? "Unknown error")
            }
            throw RepositoryError.noData
        }

        let library = data.mangas.nodes.map { $0.toDomain() }
        cachedLibrary = library
        return library
    }

    func getCategories(forceRefresh: Bool = false) async throws -> [Category] {
        if !forceRefresh, let cached = cachedCategories {
            return cached
        }

        let response: GraphQLResponse<CategoriesResponse> = try await NetworkClient.shared.executeGraphQL(
            query: GraphQLQueries.getCategories,
            responseType: GraphQLResponse<CategoriesResponse>.self
        )

        guard let data = response.data else {
            if let errors = response.errors, !errors.isEmpty {
                throw RepositoryError.graphQLError(errors.first?.message ?? "Unknown error")
            }
            throw RepositoryError.noData
        }

        var categories = data.categories.nodes.map { $0.toDomain() }
        categories.sort { $0.order < $1.order }
        cachedCategories = categories
        return categories
    }

    func createCategory(name: String) async throws -> Category {
        struct CreateCategoryResponse: Decodable {
            let createCategory: CreateCategoryResult
        }

        struct CreateCategoryResult: Decodable {
            let category: CategoryNode
        }

        let response: GraphQLResponse<CreateCategoryResponse> = try await NetworkClient.shared.executeGraphQL(
            query: GraphQLQueries.createCategory,
            variables: ["name": name],
            responseType: GraphQLResponse<CreateCategoryResponse>.self
        )

        guard let data = response.data else {
            if let errors = response.errors, !errors.isEmpty {
                throw RepositoryError.graphQLError(errors.first?.message ?? "Unknown error")
            }
            throw RepositoryError.noData
        }

        cachedCategories = nil
        return data.createCategory.category.toDomain()
    }

    func updateMangaCategories(mangaId: Int, categoryIds: [Int]) async throws {
        struct UpdateCategoriesResponse: Decodable {
            let updateMangaCategories: UpdateMangaCategoriesResult
        }

        struct UpdateMangaCategoriesResult: Decodable {
            let manga: MangaNode
        }

        let _: GraphQLResponse<UpdateCategoriesResponse> = try await NetworkClient.shared.executeGraphQL(
            query: GraphQLQueries.updateMangaCategories,
            variables: [
                "mangaId": mangaId,
                "categoryIds": categoryIds
            ],
            responseType: GraphQLResponse<UpdateCategoriesResponse>.self
        )

        cachedLibrary = nil
    }

    func clearCache() {
        cachedLibrary = nil
        cachedCategories = nil
    }

    func invalidateLibrary() {
        cachedLibrary = nil
    }
}
