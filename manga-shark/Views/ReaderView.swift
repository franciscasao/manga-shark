//
//  ReaderView.swift
//  manga-shark
//
//  Created by Francis Casao on 6/15/26.
//

import SwiftUI
import Kingfisher

/// Placeholder reader screen for a downloaded-and-extracted chapter.
///
/// Shows how many pages were extracted (and a preview of the first one) so
/// the storage-bypass pipeline can be exercised end-to-end. The real paging
/// reader is a follow-up task.
///
/// When the user navigates away, the extracted pages and downloaded `.cbz`
/// archive are deleted via `DownloadManager.cleanup(_:)` so they don't
/// accumulate on the device.
struct ReaderView: View {
    let localChapter: LocalChapterData

    var body: some View {
        VStack(spacing: 16) {
            Text(localChapter.chapter.name)
                .font(.title2.bold())

            Text("\(localChapter.pageCount) pages ready")
                .foregroundStyle(.secondary)

            if let firstPage = localChapter.pageURLs.first {
                KFImage(firstPage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding()
        .navigationTitle("Reader")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            let data = localChapter
            Task {
                await DownloadManager.shared.cleanup(data)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReaderView(localChapter: .preview)
    }
}
