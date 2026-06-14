//
//  LocalChapterData.swift
//  manga-shark
//
//  Created by Francis Casao on 6/15/26.
//

import Foundation

/// The result of `DownloadManager.prepareChapter(for:onProgress:)`: a chapter
/// whose `.cbz` archive has been downloaded and extracted to local disk,
/// ready for the reader to display.
///
/// Holds the on-disk locations of the archive and extracted pages so the
/// reader can clean them up (`DownloadManager.cleanup(_:)`) once the user is
/// done with the chapter.
struct LocalChapterData: Identifiable, Hashable {
    let chapter: Chapter

    /// Ordered local file URLs for each extracted page image, in reading order.
    let pageURLs: [URL]

    /// Location of the downloaded `.cbz` archive in the cache directory.
    let archiveURL: URL

    /// Directory the archive's pages were extracted into.
    let extractionDirectory: URL

    var id: Int { chapter.id }

    var pageCount: Int { pageURLs.count }
}

#if DEBUG
extension LocalChapterData {
    static let preview = LocalChapterData(
        chapter: .preview,
        pageURLs: (1...12).map { URL(fileURLWithPath: "/tmp/preview/page-\($0).jpg") },
        archiveURL: URL(fileURLWithPath: "/tmp/preview/1-1.0.cbz"),
        extractionDirectory: URL(fileURLWithPath: "/tmp/preview/1-1.0")
    )
}
#endif
