//
//  ImageDownsampler.swift
//  manga-shark
//
//  Created by Francis Casao on 6/15/26.
//

import Foundation
import ImageIO
import CoreGraphics

/// Memory-efficient image decoding for manhwa pages.
///
/// Raw manhwa page images can be extremely tall (often several thousand
/// pixels) and a `LazyVStack` of full-resolution `UIImage`s will balloon
/// memory usage and cause scroll jank. `ImageIO`'s thumbnail generation
/// decodes images at a target size without first materializing the full
/// decoded bitmap, which Kingfisher can also leverage via its
/// `DownsamplingImageProcessor`.
///
/// This type exists as a fallback/utility for cases where an image needs
/// to be downsampled outside of Kingfisher's pipeline (e.g. pre-warming a
/// disk cache after extraction).
enum ImageDownsampler {
    /// Creates a downsampled `CGImage` from the image at `url`, constrained
    /// to `maxPixelSize` on its longest edge, without decoding the full
    /// image into memory first.
    ///
    /// TODO: Wire this into the chapter prefetch step in
    /// `ChapterWindowManager`/the manhwa reader once that's rebuilt, so
    /// off-screen pages are pre-downsampled before they scroll into view.
    static func downsample(imageAt url: URL, to maxPixelSize: Int) -> CGImage? {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return nil
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
    }
}
