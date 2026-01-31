import SwiftUI
import UIKit

struct ManhwaReaderRepresentable: UIViewControllerRepresentable {
    let pages: [Page]
    let chapterId: Int
    let serverUrl: String
    let authHeader: String?
    let initialScrollOffset: CGFloat?

    var onTapToToggleControls: (() -> Void)?
    var onProgressUpdate: ((CGFloat, CGFloat, Int) -> Void)?
    var onReachEnd: (() -> Void)?
    var onWillDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> ManhwaReaderViewController {
        let controller = ManhwaReaderViewController(
            pages: pages,
            chapterId: chapterId,
            serverUrl: serverUrl,
            authHeader: authHeader,
            initialScrollOffset: initialScrollOffset
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

        func manhwaReaderDidUpdateProgress(scrollPercentage: CGFloat, offsetY: CGFloat, visiblePageIndex: Int) {
            parent.onProgressUpdate?(scrollPercentage, offsetY, visiblePageIndex)
        }

        func manhwaReaderDidReachEnd() {
            parent.onReachEnd?()
        }

        func manhwaReaderWillDismiss() {
            parent.onWillDismiss?()
        }
    }
}

extension ManhwaReaderRepresentable {
    func onTapToToggleControls(_ action: @escaping () -> Void) -> ManhwaReaderRepresentable {
        var copy = self
        copy.onTapToToggleControls = action
        return copy
    }

    func onProgressUpdate(_ action: @escaping (CGFloat, CGFloat, Int) -> Void) -> ManhwaReaderRepresentable {
        var copy = self
        copy.onProgressUpdate = action
        return copy
    }

    func onReachEnd(_ action: @escaping () -> Void) -> ManhwaReaderRepresentable {
        var copy = self
        copy.onReachEnd = action
        return copy
    }

    func onWillDismiss(_ action: @escaping () -> Void) -> ManhwaReaderRepresentable {
        var copy = self
        copy.onWillDismiss = action
        return copy
    }
}
