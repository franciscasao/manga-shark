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

    func updateProgress(chapterId: Int, lastPageRead: Int, isRead: Bool) async {
        // Local progress is now managed by ReadingProgressManager (SwiftData + CloudKit)
        // This method only handles server sync for non-iOS clients

        // Server sync (detached, non-blocking, global progress)
        Task.detached(priority: .utility) {
            await Self.syncProgressToServer(
                chapterId: chapterId,
                lastPageRead: lastPageRead,
                isRead: isRead
            )
        }
    }

    private static func syncProgressToServer(chapterId: Int, lastPageRead: Int, isRead: Bool) async {
        do {
            let _: GraphQLResponse<UpdateChapterResponse> = try await NetworkClient.shared.executeGraphQL(
                query: GraphQLQueries.updateChapterProgress,
                variables: [
                    "chapterId": chapterId,
                    "lastPageRead": lastPageRead,
                    "isRead": isRead
                ],
                responseType: GraphQLResponse<UpdateChapterResponse>.self
            )
            print("✅ [ChapterRepository] Server sync successful for chapter \(chapterId)")
        } catch {
            print("⚠️ [ChapterRepository] Server sync failed (non-critical) for chapter \(chapterId): \(error)")
        }
    }

    func markChaptersRead(chapterIds: [Int], isRead: Bool) async {
        // Local progress is now managed by ReadingProgressManager (SwiftData + CloudKit)
        // Update each chapter in SwiftData
        await MainActor.run {
            for chapterId in chapterIds {
                ReadingProgressManager.shared.updateProgress(
                    chapterId: String(chapterId),
                    seriesId: "",  // Will be updated on next read
                    percentage: isRead ? 1.0 : 0.0,
                    pageIndex: 0,
                    isRead: isRead
                )
            }
        }

        // Server sync (detached, non-blocking, global progress)
        Task.detached(priority: .utility) {
            await Self.syncChaptersReadToServer(chapterIds: chapterIds, isRead: isRead)
        }
    }

    private static func syncChaptersReadToServer(chapterIds: [Int], isRead: Bool) async {
        do {
            let _: GraphQLResponse<UpdateChaptersResponse> = try await NetworkClient.shared.executeGraphQL(
                query: GraphQLQueries.markChaptersRead,
                variables: [
                    "chapterIds": chapterIds,
                    "isRead": isRead
                ],
                responseType: GraphQLResponse<UpdateChaptersResponse>.self
            )
            print("✅ [ChapterRepository] Server bulk sync successful for \(chapterIds.count) chapters")
        } catch {
            print("⚠️ [ChapterRepository] Server bulk sync failed (non-critical) for \(chapterIds.count) chapters: \(error)")
        }
    }
}
