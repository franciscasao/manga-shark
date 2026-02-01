import Foundation
import SwiftData

// MARK: - Reading Progress Manager

@MainActor
final class ReadingProgressManager {
    static let shared = ReadingProgressManager()

    private var modelContainer: ModelContainer?
    private var pendingUpdates: [String: PendingUpdate] = [:]
    private var saveTimer: Timer?
    private let saveDebounceInterval: TimeInterval = 0.5

    private var activeChapterId: String?

    private init() {}

    // MARK: - Configuration

    func configure(with container: ModelContainer) {
        self.modelContainer = container
    }

    // MARK: - Active Reading Guard

    func beginReading(chapterId: String) {
        activeChapterId = chapterId
    }

    func endReading() {
        flushPendingUpdates()
        activeChapterId = nil
    }

    func shouldApplyRemoteUpdate(for chapterId: String) -> Bool {
        return chapterId != activeChapterId
    }

    // MARK: - Progress Operations

    func getProgress(for chapterId: String) async -> ProgressData? {
        guard let container = modelContainer else { return nil }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ChapterProgress>(
            predicate: #Predicate { $0.chapterId == chapterId }
        )

        do {
            let results = try context.fetch(descriptor)
            if let progress = results.first {
                return ProgressData(
                    lastPageIndex: progress.lastPageIndex,
                    lastReadPercentage: progress.lastReadPercentage,
                    isRead: progress.isRead
                )
            }
        } catch {
            print("⚠️ [ReadingProgressManager] Failed to fetch progress for chapter \(chapterId): \(error)")
        }
        return nil
    }

    func getReadStatus(for chapterIds: [Int]) async -> [Int: Bool] {
        guard let container = modelContainer else { return [:] }

        let context = ModelContext(container)
        var readStatus: [Int: Bool] = [:]

        for chapterId in chapterIds {
            let chapterIdStr = String(chapterId)
            let descriptor = FetchDescriptor<ChapterProgress>(
                predicate: #Predicate { $0.chapterId == chapterIdStr }
            )

            if let results = try? context.fetch(descriptor),
               let progress = results.first {
                readStatus[chapterId] = progress.isRead
            }
        }

        return readStatus
    }

    /// Quick method to mark a chapter as 100% complete during chapter transitions
    /// This method bypasses debounce to ensure immediate persistence
    func markChapterComplete(chapterId: String, seriesId: String) async {
        guard let container = modelContainer else { return }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ChapterProgress>(
            predicate: #Predicate { $0.chapterId == chapterId }
        )

        do {
            let results = try context.fetch(descriptor)
            let now = Date()

            if let existingProgress = results.first {
                existingProgress.lastReadPercentage = 1.0
                existingProgress.isRead = true
                existingProgress.updatedAt = now
            } else {
                let newProgress = ChapterProgress(
                    chapterId: chapterId,
                    seriesId: seriesId,
                    lastReadPercentage: 1.0,
                    updatedAt: now,
                    isRead: true,
                    lastPageIndex: Int.max
                )
                context.insert(newProgress)
            }

            try context.save()
            print("✅ [ReadingProgressManager] Chapter \(chapterId) marked complete immediately")
        } catch {
            print("⚠️ [ReadingProgressManager] Failed to mark chapter complete: \(error)")
        }

        // Server sync
        await Self.syncProgressToServer(
            chapterId: chapterId,
            lastPageRead: Int.max,
            isRead: true
        )
    }

    func updateProgress(
        chapterId: String,
        seriesId: String,
        percentage: Double,
        pageIndex: Int,
        isRead: Bool
    ) {
        let update = PendingUpdate(
            chapterId: chapterId,
            seriesId: seriesId,
            percentage: percentage,
            pageIndex: pageIndex,
            isRead: isRead,
            timestamp: Date()
        )

        pendingUpdates[chapterId] = update

        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveDebounceInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.flushPendingUpdates()
            }
        }
    }

    private func flushPendingUpdates() {
        guard let container = modelContainer else { return }

        let updates = pendingUpdates
        pendingUpdates.removeAll()
        saveTimer?.invalidate()

        Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)

            for (chapterId, update) in updates {
                do {
                    let descriptor = FetchDescriptor<ChapterProgress>(
                        predicate: #Predicate { $0.chapterId == chapterId }
                    )
                    let results = try context.fetch(descriptor)

                    if let existingProgress = results.first {
                        // Conflict resolution: most recent wins
                        if update.timestamp > existingProgress.updatedAt {
                            existingProgress.lastReadPercentage = update.percentage
                            existingProgress.lastPageIndex = update.pageIndex
                            existingProgress.isRead = update.isRead
                            existingProgress.updatedAt = update.timestamp
                        }
                    } else {
                        let newProgress = ChapterProgress(
                            chapterId: chapterId,
                            seriesId: update.seriesId,
                            lastReadPercentage: update.percentage,
                            updatedAt: update.timestamp,
                            isRead: update.isRead,
                            lastPageIndex: update.pageIndex
                        )
                        context.insert(newProgress)
                    }

                    try context.save()
                    print("✅ [ReadingProgressManager] Local progress saved for chapter \(chapterId)")
                } catch {
                    print("⚠️ [ReadingProgressManager] Failed to save progress for chapter \(chapterId): \(error)")
                }

                // Phase 2: Server sync
                await Self.syncProgressToServer(
                    chapterId: chapterId,
                    lastPageRead: update.pageIndex,
                    isRead: update.isRead
                )
            }
        }
    }

    // MARK: - Server Sync

    static func syncProgressToServer(chapterId: String, lastPageRead: Int, isRead: Bool) async {
        guard let chapterIdInt = Int(chapterId) else { return }

        do {
            let _: GraphQLResponse<UpdateChapterResponse> = try await NetworkClient.shared.executeGraphQL(
                query: GraphQLQueries.updateChapterProgress,
                variables: [
                    "chapterId": chapterIdInt,
                    "lastPageRead": lastPageRead,
                    "isRead": isRead
                ],
                responseType: GraphQLResponse<UpdateChapterResponse>.self
            )
            print("✅ [ReadingProgressManager] Server sync successful for chapter \(chapterId)")
        } catch {
            print("⚠️ [ReadingProgressManager] Server sync failed (non-critical) for chapter \(chapterId): \(error)")
        }
    }

    // MARK: - Percentage/Offset Conversion

    /// Calculate scroll percentage from offset
    static func calculatePercentage(offset: CGFloat, totalHeight: CGFloat, viewHeight: CGFloat) -> Double {
        let scrollableHeight = totalHeight - viewHeight
        guard scrollableHeight > 0 else { return 0 }
        return Double(min(1, max(0, offset / scrollableHeight)))
    }

    /// Calculate offset from percentage
    static func calculateOffset(percentage: Double, totalHeight: CGFloat, viewHeight: CGFloat) -> CGFloat {
        let scrollableHeight = totalHeight - viewHeight
        guard scrollableHeight > 0 else { return 0 }
        return CGFloat(percentage) * scrollableHeight
    }

    /// Calculate percentage from page index (for paged mode)
    static func calculatePercentage(pageIndex: Int, totalPages: Int) -> Double {
        guard totalPages > 1 else { return 0 }
        return Double(pageIndex) / Double(totalPages - 1)
    }

    /// Calculate page index from percentage (for paged mode)
    static func calculatePageIndex(percentage: Double, totalPages: Int) -> Int {
        guard totalPages > 1 else { return 0 }
        return Int(round(percentage * Double(totalPages - 1)))
    }
}

// MARK: - Supporting Types

private struct PendingUpdate {
    let chapterId: String
    let seriesId: String
    let percentage: Double
    let pageIndex: Int
    let isRead: Bool
    let timestamp: Date
}

/// Cross-platform progress data structure
struct ProgressData {
    let lastPageIndex: Int
    let lastReadPercentage: Double
    let isRead: Bool
}
