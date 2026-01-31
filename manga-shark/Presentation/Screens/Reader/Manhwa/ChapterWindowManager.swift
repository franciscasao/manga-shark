import Foundation
import UIKit
import Kingfisher

/// Manages memory windowing for infinite scroll, keeping only nearby chapters loaded
final class ChapterWindowManager {
    var chapters: [ChapterSection] = []
    private(set) var activeChapterIndex: Int = 0
    let windowRadius: Int = 1  // Chapters to keep loaded around active

    private let serverUrl: String
    private var updateDebounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.3

    weak var delegate: ChapterWindowManagerDelegate?

    init(serverUrl: String) {
        self.serverUrl = serverUrl
    }

    // MARK: - Chapter Management

    /// Initialize with the starting chapter
    func setInitialChapter(_ chapter: Chapter, pages: [Page]) {
        let section = ChapterSection(
            chapter: chapter,
            pages: pages,
            pageHeights: [:],
            loadState: .loaded
        )
        chapters = [section]
        activeChapterIndex = 0
    }

    /// Append a chapter at the end (for forward scrolling)
    func appendChapter(_ chapter: Chapter, pages: [Page]) -> Int {
        let section = ChapterSection(
            chapter: chapter,
            pages: pages,
            pageHeights: [:],
            loadState: .loaded
        )
        chapters.append(section)
        return chapters.count - 1
    }

    /// Prepend a chapter at the beginning (for backward scrolling)
    func prependChapter(_ chapter: Chapter, pages: [Page]) {
        let section = ChapterSection(
            chapter: chapter,
            pages: pages,
            pageHeights: [:],
            loadState: .loaded
        )
        chapters.insert(section, at: 0)
        // Adjust active index since we inserted at beginning
        activeChapterIndex += 1
    }

    /// Check if a chapter is already in the window
    func containsChapter(_ chapterId: Int) -> Bool {
        chapters.contains { $0.chapter.id == chapterId }
    }

    /// Get the section index for a chapter ID
    func sectionIndex(for chapterId: Int) -> Int? {
        chapters.firstIndex { $0.chapter.id == chapterId }
    }

    // MARK: - Window Management

    /// Update the active chapter and manage memory window
    func updateWindow(activeSection: Int) {
        // Debounce rapid updates during fast scrolling
        updateDebounceTimer?.invalidate()
        updateDebounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            self?.performWindowUpdate(activeSection: activeSection)
        }
    }

    /// Force immediate window update (for scroll settle)
    func updateWindowImmediate(activeSection: Int) {
        updateDebounceTimer?.invalidate()
        performWindowUpdate(activeSection: activeSection)
    }

    private func performWindowUpdate(activeSection: Int) {
        guard activeSection >= 0 && activeSection < chapters.count else { return }

        activeChapterIndex = activeSection

        let windowStart = max(0, activeSection - windowRadius)
        let windowEnd = min(chapters.count - 1, activeSection + windowRadius)

        // Load chapters entering window
        for i in windowStart...windowEnd {
            if chapters[i].loadState == .unloaded {
                loadChapterImages(at: i)
            }
        }

        // Unload chapters leaving window (preserve heights!)
        for i in 0..<chapters.count {
            if i < windowStart || i > windowEnd {
                if chapters[i].loadState == .loaded {
                    unloadChapterImages(at: i)
                }
            }
        }
    }

    // MARK: - Image Memory Management

    private func loadChapterImages(at index: Int) {
        guard index >= 0 && index < chapters.count else { return }
        chapters[index].loadState = .loaded
        delegate?.chapterWindowManager(self, didLoadChapterAt: index)
    }

    private func unloadChapterImages(at index: Int) {
        guard index >= 0 && index < chapters.count else { return }

        let chapter = chapters[index]

        // Clear from Kingfisher memory cache only (keep disk cache)
        let cache = KingfisherManager.shared.cache
        for page in chapter.pages {
            if let urlString = page.effectiveUrl,
               let url = urlString.toManhwaImageURL(serverUrl: serverUrl) {
                cache.removeImage(forKey: url.cacheKey, fromMemory: true, fromDisk: false)
            }
        }

        // Heights remain in chapter.pageHeights - no layout shift!
        chapters[index].loadState = .unloaded
        delegate?.chapterWindowManager(self, didUnloadChapterAt: index)
    }

    // MARK: - Height Caching

    /// Cache the height for a page in a chapter
    func cachePageHeight(_ height: CGFloat, forPage pageIndex: Int, inSection sectionIndex: Int) {
        guard sectionIndex >= 0 && sectionIndex < chapters.count else { return }
        chapters[sectionIndex].pageHeights[pageIndex] = height
    }

    /// Get cached height for a page, or nil if not cached
    func cachedPageHeight(forPage pageIndex: Int, inSection sectionIndex: Int) -> CGFloat? {
        guard sectionIndex >= 0 && sectionIndex < chapters.count else { return nil }
        return chapters[sectionIndex].pageHeights[pageIndex]
    }

    // MARK: - Cleanup

    func invalidate() {
        updateDebounceTimer?.invalidate()
        updateDebounceTimer = nil
    }
}

// MARK: - Delegate Protocol

protocol ChapterWindowManagerDelegate: AnyObject {
    func chapterWindowManager(_ manager: ChapterWindowManager, didLoadChapterAt index: Int)
    func chapterWindowManager(_ manager: ChapterWindowManager, didUnloadChapterAt index: Int)
}
