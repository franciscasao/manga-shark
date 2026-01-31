import Foundation
import SwiftData

// MARK: - iOS 17+ Implementation

@available(iOS 17, *)
@MainActor
final class ReadingProgressManageriOS17 {
    static let shared = ReadingProgressManageriOS17()

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

    func getProgress(for chapterId: String) async -> ChapterProgress? {
        guard let container = modelContainer else { return nil }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ChapterProgress>(
            predicate: #Predicate { $0.chapterId == chapterId }
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            print("⚠️ [ReadingProgressManager] Failed to fetch progress for chapter \(chapterId): \(error)")
            return nil
        }
    }

    func getReadStatus(for chapterIds: [String]) async -> [String: Bool] {
        guard let container = modelContainer else { return [:] }

        let context = ModelContext(container)
        var readStatus: [String: Bool] = [:]

        for chapterId in chapterIds {
            let descriptor = FetchDescriptor<ChapterProgress>(
                predicate: #Predicate { $0.chapterId == chapterId }
            )

            if let results = try? context.fetch(descriptor),
               let progress = results.first {
                readStatus[chapterId] = progress.isRead
            }
        }

        return readStatus
    }

    func markChapterCompleteImmediate(
        chapterId: String,
        seriesId: String
    ) async {
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
        await ReadingProgressManager.syncProgressToServer(
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
                await ReadingProgressManager.syncProgressToServer(
                    chapterId: chapterId,
                    lastPageRead: update.pageIndex,
                    isRead: update.isRead
                )
            }
        }
    }
}

// MARK: - Cross-Platform Wrapper

@MainActor
final class ReadingProgressManager {
    static let shared = ReadingProgressManager()

    private init() {}

    // MARK: - Configuration

    @available(iOS 17, *)
    func configure(with container: ModelContainer) {
        ReadingProgressManageriOS17.shared.configure(with: container)
    }

    // MARK: - Active Reading Guard

    func beginReading(chapterId: String) {
        if #available(iOS 17, *) {
            ReadingProgressManageriOS17.shared.beginReading(chapterId: chapterId)
        }
        // On iOS 16, we don't need active reading guard since progress isn't synced via CloudKit
    }

    func endReading() {
        if #available(iOS 17, *) {
            ReadingProgressManageriOS17.shared.endReading()
        }
    }

    /// Quick method to mark a chapter as 100% complete during chapter transitions
    /// This method bypasses debounce to ensure immediate persistence
    func markChapterComplete(chapterId: String, seriesId: String) async {
        if #available(iOS 17, *) {
            await ReadingProgressManageriOS17.shared.markChapterCompleteImmediate(
                chapterId: chapterId,
                seriesId: seriesId
            )
        } else {
            // iOS 16: Use CoreData directly (already synchronous per-call)
            let deviceId = DeviceIdentifierManager.shared.deviceId
            if let chapterIdInt = Int(chapterId) {
                try? await CoreDataStack.shared.updateChapterProgress(
                    chapterId: chapterIdInt,
                    deviceId: deviceId,
                    lastPageRead: Int.max,
                    isRead: true
                )
            }
            await Self.syncProgressToServer(chapterId: chapterId, lastPageRead: Int.max, isRead: true)
        }
    }

    /// Get read status for multiple chapters from the correct data source per iOS version
    func getReadStatus(for chapterIds: [Int]) async -> [Int: Bool] {
        if #available(iOS 17, *) {
            let stringIds = chapterIds.map { String($0) }
            let result = await ReadingProgressManageriOS17.shared.getReadStatus(for: stringIds)
            // Convert back to Int keys
            var intResult: [Int: Bool] = [:]
            for (key, value) in result {
                if let intKey = Int(key) {
                    intResult[intKey] = value
                }
            }
            return intResult
        } else {
            // iOS 16: Use CoreData
            let deviceId = DeviceIdentifierManager.shared.deviceId
            return (try? await CoreDataStack.shared.getChaptersReadStatus(
                chapterIds: chapterIds,
                deviceId: deviceId
            )) ?? [:]
        }
    }

    // MARK: - Progress Operations

    func getProgress(for chapterId: String) async -> ProgressData? {
        if #available(iOS 17, *) {
            if let progress = await ReadingProgressManageriOS17.shared.getProgress(for: chapterId) {
                return ProgressData(
                    lastPageIndex: progress.lastPageIndex,
                    lastReadPercentage: progress.lastReadPercentage,
                    isRead: progress.isRead
                )
            }
        } else {
            // iOS 16 fallback: use CoreData
            let deviceId = DeviceIdentifierManager.shared.deviceId
            if let chapterId = Int(chapterId),
               let progress = try? await CoreDataStack.shared.getChapterProgress(chapterId: chapterId, deviceId: deviceId) {
                return ProgressData(
                    lastPageIndex: progress.lastPageRead,
                    lastReadPercentage: 0,  // Not tracked in iOS 16
                    isRead: progress.isRead
                )
            }
        }
        return nil
    }

    func updateProgress(
        chapterId: String,
        seriesId: String,
        percentage: Double,
        pageIndex: Int,
        isRead: Bool
    ) {
        if #available(iOS 17, *) {
            ReadingProgressManageriOS17.shared.updateProgress(
                chapterId: chapterId,
                seriesId: seriesId,
                percentage: percentage,
                pageIndex: pageIndex,
                isRead: isRead
            )
        } else {
            // iOS 16 fallback: use CoreData
            Task {
                let deviceId = DeviceIdentifierManager.shared.deviceId
                if let chapterIdInt = Int(chapterId) {
                    try? await CoreDataStack.shared.updateChapterProgress(
                        chapterId: chapterIdInt,
                        deviceId: deviceId,
                        lastPageRead: pageIndex,
                        isRead: isRead
                    )
                }

                // Also sync to server
                await Self.syncProgressToServer(
                    chapterId: chapterId,
                    lastPageRead: pageIndex,
                    isRead: isRead
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
