import Foundation

/// Represents a chapter section in the infinite scroll view
struct ChapterSection: Identifiable {
    let chapter: Chapter
    var pages: [Page]
    var pageHeights: [Int: CGFloat]  // Cached heights by page index
    var loadState: ChapterLoadState

    var id: Int { chapter.id }

    init(chapter: Chapter, pages: [Page], pageHeights: [Int: CGFloat] = [:], loadState: ChapterLoadState = .notLoaded) {
        self.chapter = chapter
        self.pages = pages
        self.pageHeights = pageHeights
        self.loadState = loadState
    }
}

/// Load state for chapter images in the infinite scroll
enum ChapterLoadState {
    case notLoaded      // Pages not fetched
    case loading        // Fetching pages
    case loaded         // Pages available
    case unloaded       // Images deallocated, heights preserved
}

/// Direction of scroll for chapter transitions
enum ScrollDirection {
    case forward
    case backward
}
