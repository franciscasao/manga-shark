import Foundation

actor ChapterRepository {
    static let shared = ChapterRepository()

    private init() {}

    func getChapterPages(chapterId: Int) async throws -> [Page] {
        let response: GraphQLResponse<ChapterPagesResponse> = try await NetworkClient.shared.executeGraphQL(
            query: GraphQLQueries.getChapterPages,
            variables: ["chapterId": chapterId],
            responseType: GraphQLResponse<ChapterPagesResponse>.self
        )

        guard let data = response.data else {
            if let errors = response.errors, !errors.isEmpty {
                throw RepositoryError.graphQLError(errors.first?.message ?? "Unknown error")
            }
            throw RepositoryError.noData
        }

        return data.fetchChapterPages.pages.enumerated().map { index, url in
            Page(
                chapterId: chapterId,
                index: index,
                imageUrl: url
            )
        }
    }

    func updateProgress(chapterId: Int, lastPageRead: Int, isRead: Bool) async throws {
        let _: GraphQLResponse<UpdateChapterResponse> = try await NetworkClient.shared.executeGraphQL(
            query: GraphQLQueries.updateChapterProgress,
            variables: [
                "chapterId": chapterId,
                "lastPageRead": lastPageRead,
                "isRead": isRead
            ],
            responseType: GraphQLResponse<UpdateChapterResponse>.self
        )
    }

    func markChaptersRead(chapterIds: [Int], isRead: Bool) async throws {
        let _: GraphQLResponse<UpdateChaptersResponse> = try await NetworkClient.shared.executeGraphQL(
            query: GraphQLQueries.markChaptersRead,
            variables: [
                "chapterIds": chapterIds,
                "isRead": isRead
            ],
            responseType: GraphQLResponse<UpdateChaptersResponse>.self
        )
    }
}
