import Foundation

actor LibraryRepository {
    static let shared = LibraryRepository()

    private var cachedLibrary: [Manga]?
    private var cachedCategories: [Category]?

    private init() {}

    func getLibrary(forceRefresh: Bool = false) async throws -> [Manga] {
        print("📚 [LibraryRepository] Loading library (forceRefresh: \(forceRefresh))")

        if !forceRefresh, let cached = cachedLibrary {
            print("💾 [LibraryRepository] Using cached library (\(cached.count) items)")
            return cached
        }

        print("🌐 [LibraryRepository] Fetching library from network")
        let response: GraphQLResponse<LibraryResponse> = try await NetworkClient.shared.executeGraphQL(
            query: GraphQLQueries.getLibrary,
            responseType: GraphQLResponse<LibraryResponse>.self
        )

        print("📚 [LibraryRepository] Response received")
        print("📚 [LibraryRepository] Has data: \(response.data != nil)")
        print("📚 [LibraryRepository] Errors count: \(response.errors?.count ?? 0)")

        if let errors = response.errors {
            print("❌ [LibraryRepository] GraphQL errors: \(errors)")
        }

        guard let data = response.data else {
            print("❌ [LibraryRepository] No data in response")
            if let errors = response.errors, !errors.isEmpty {
                let errorMsg = errors.first?.message ?? "Unknown error"
                print("❌ [LibraryRepository] Throwing GraphQL error: \(errorMsg)")
                throw RepositoryError.graphQLError(errorMsg)
            }
            print("❌ [LibraryRepository] No data and no errors - throwing noData")
            throw RepositoryError.noData
        }

        print("📚 [LibraryRepository] Data received, nodes count: \(data.mangas.nodes.count)")
        let library = data.mangas.nodes.map { $0.toDomain() }
        print("✅ [LibraryRepository] Successfully loaded \(library.count) manga")
        print("📚 [LibraryRepository] Manga titles: \(library.map { $0.title })")

        cachedLibrary = library
        return library
    }

    func getCategories(forceRefresh: Bool = false) async throws -> [Category] {
        print("📂 [LibraryRepository] Loading categories (forceRefresh: \(forceRefresh))")

        if !forceRefresh, let cached = cachedCategories {
            print("💾 [LibraryRepository] Using cached categories (\(cached.count) items)")
            return cached
        }

        print("🌐 [LibraryRepository] Fetching categories from network")
        let response: GraphQLResponse<CategoriesResponse> = try await NetworkClient.shared.executeGraphQL(
            query: GraphQLQueries.getCategories,
            responseType: GraphQLResponse<CategoriesResponse>.self
        )

        print("📂 [LibraryRepository] Categories response received")
        print("📂 [LibraryRepository] Has data: \(response.data != nil)")

        guard let data = response.data else {
            print("❌ [LibraryRepository] No category data in response")
            if let errors = response.errors, !errors.isEmpty {
                let errorMsg = errors.first?.message ?? "Unknown error"
                print("❌ [LibraryRepository] Categories error: \(errorMsg)")
                throw RepositoryError.graphQLError(errorMsg)
            }
            throw RepositoryError.noData
        }

        var categories = data.categories.nodes.map { $0.toDomain() }
        categories.sort { $0.order < $1.order }
        print("✅ [LibraryRepository] Successfully loaded \(categories.count) categories")

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
