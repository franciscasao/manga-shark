//
//  MangaCoverCard.swift
//  manga-shark
//
//  Created by Francis Casao on 6/15/26.
//

import SwiftUI
import Kingfisher

/// A single library grid cell: a manga's cover thumbnail with its title
/// beneath it.
///
/// Covers are loaded via Kingfisher, which caches them in memory and on
/// disk — important since the thumbnails are fetched over Tailscale from
/// the Suwayomi server.
struct MangaCoverCard: View {
    let manga: Manga

    /// Roughly matches the grid cell width used by `LibraryView`'s adaptive
    /// columns; used to downsample covers to a sensible decode size.
    private let coverWidth: CGFloat = 110

    private var thumbnailURL: URL? {
        guard let thumbnailUrl = manga.thumbnailUrl else { return nil }
        return AppConfig.absoluteURL(for: thumbnailUrl)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            KFImage(thumbnailURL)
                .placeholder {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.secondary.opacity(0.15))
                        ProgressView()
                    }
                }
                .setProcessor(
                    DownsamplingImageProcessor(size: CGSize(width: coverWidth * 2, height: coverWidth * 3))
                )
                .scaleFactor(UIScreen.main.scale)
                .cacheOriginalImage()
                .fade(duration: 0.2)
                .resizable()
                .aspectRatio(2 / 3, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.separator, lineWidth: 0.5)
                )

            Text(manga.title)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 16)], spacing: 16) {
        ForEach(Manga.previewList) { manga in
            MangaCoverCard(manga: manga)
        }
    }
    .padding()
}
