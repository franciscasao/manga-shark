import SwiftUI
import UIKit

struct ManhwaReaderRepresentable: UIViewControllerRepresentable {
    let initialChapter: Chapter
    let initialPages: [Page]
    let allChapters: [Chapter]
    let serverUrl: String
    let authHeader: String?
    let initialScrollPercentage: Double?

    var onTapToToggleControls: (() -> Void)?
    var onProgressUpdate: ((Chapter, CGFloat, Int) -> Void)?
    var onWillDismiss: (() -> Void)?
    var onChapterChange: ((Chapter, Chapter, ScrollDirection) -> Void)?
    var onNeedsNextChapter: ((Chapter, @escaping ([Page]?, Chapter?) -> Void) -> Void)?
    var onNeedsPreviousChapter: ((Chapter, @escaping ([Page]?, Chapter?) -> Void) -> Void)?
    var onReachLastChapter: (() -> Void)?

    func makeUIViewController(context: Context) -> ManhwaReaderViewController {
        let controller = ManhwaReaderViewController(
            initialChapter: initialChapter,
            initialPages: initialPages,
            allChapters: allChapters,
            serverUrl: serverUrl,
            authHeader: authHeader,
            initialScrollPercentage: initialScrollPercentage
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ManhwaReaderViewController, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, ManhwaReaderViewControllerDelegate {
        var parent: ManhwaReaderRepresentable

        init(_ parent: ManhwaReaderRepresentable) {
            self.parent = parent
        }

        func manhwaReaderDidTapToToggleControls() {
            parent.onTapToToggleControls?()
        }

        func manhwaReaderDidUpdateProgress(chapter: Chapter, scrollPercentage: CGFloat, pageIndex: Int) {
            parent.onProgressUpdate?(chapter, scrollPercentage, pageIndex)
        }

        func manhwaReaderWillDismiss() {
            parent.onWillDismiss?()
        }

        func manhwaReaderDidChangeChapter(from oldChapter: Chapter, to newChapter: Chapter, direction: ScrollDirection) {
            parent.onChapterChange?(oldChapter, newChapter, direction)
        }

        func manhwaReaderNeedsNextChapter(after chapter: Chapter, completion: @escaping ([Page]?, Chapter?) -> Void) {
            if let handler = parent.onNeedsNextChapter {
                handler(chapter, completion)
            } else {
                completion(nil, nil)
            }
        }

        func manhwaReaderNeedsPreviousChapter(before chapter: Chapter, completion: @escaping ([Page]?, Chapter?) -> Void) {
            if let handler = parent.onNeedsPreviousChapter {
                handler(chapter, completion)
            } else {
                completion(nil, nil)
            }
        }

        func manhwaReaderDidReachLastChapter() {
            parent.onReachLastChapter?()
        }
    }
}

extension ManhwaReaderRepresentable {
    func onTapToToggleControls(_ action: @escaping () -> Void) -> ManhwaReaderRepresentable {
        var copy = self
        copy.onTapToToggleControls = action
        return copy
    }

    func onProgressUpdate(_ action: @escaping (Chapter, CGFloat, Int) -> Void) -> ManhwaReaderRepresentable {
        var copy = self
        copy.onProgressUpdate = action
        return copy
    }

    func onWillDismiss(_ action: @escaping () -> Void) -> ManhwaReaderRepresentable {
        var copy = self
        copy.onWillDismiss = action
        return copy
    }

    func onChapterChange(_ action: @escaping (Chapter, Chapter, ScrollDirection) -> Void) -> ManhwaReaderRepresentable {
        var copy = self
        copy.onChapterChange = action
        return copy
    }

    func onNeedsNextChapter(_ action: @escaping (Chapter, @escaping ([Page]?, Chapter?) -> Void) -> Void) -> ManhwaReaderRepresentable {
        var copy = self
        copy.onNeedsNextChapter = action
        return copy
    }

    func onNeedsPreviousChapter(_ action: @escaping (Chapter, @escaping ([Page]?, Chapter?) -> Void) -> Void) -> ManhwaReaderRepresentable {
        var copy = self
        copy.onNeedsPreviousChapter = action
        return copy
    }

    func onReachLastChapter(_ action: @escaping () -> Void) -> ManhwaReaderRepresentable {
        var copy = self
        copy.onReachLastChapter = action
        return copy
    }
}
