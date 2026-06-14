# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the project
xcodebuild -project manga-shark.xcodeproj -scheme manga-shark build

# Build for simulator (use available simulator name like "iPhone 17")
xcodebuild -project manga-shark.xcodeproj -scheme manga-shark -destination 'platform=iOS Simulator,name=iPhone 17' build

# Clean build
xcodebuild -project manga-shark.xcodeproj -scheme manga-shark clean build
```

**Dependencies** (SPM): [Kingfisher](https://github.com/onevcat/Kingfisher) for image loading,
caching, and downsampling; [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) for `.cbz`
extraction. Requires Xcode 16.2+, targets iOS 17+.

**Note**: No test target exists in this project.

## Architecture

Manga Shark is a SwiftUI manhwa reader that treats a self-hosted **Suwayomi** instance purely as a
**metadata** source and reads chapter content directly from a separate **Nginx/JuiceFS file server**.

### Why the split backend

Suwayomi is prone to dropping deleted chapters from its own database. To avoid losing access to
chapters, the app never requests page images from Suwayomi. Instead:

1. **Suwayomi REST API** (`SuwayomiService`) — catalog browsing, manga details, chapter lists/metadata.
2. **Nginx file server** (`DownloadManager`) — hosts raw `.cbz` chapter archives (JuiceFS/S3 backed).
   The app downloads the archive directly by URL, unzips it on-device with ZIPFoundation, and
   renders the extracted images. Suwayomi is not in this path at all.

Both endpoints are configured in `Utilities/AppConfig.swift`.

### Folder Structure

- `Models/` — `Codable` domain models mirroring Suwayomi REST response shapes (`Manga`, `Chapter`,
  `Source`). Each has a `#if DEBUG` `.preview`/`.previewList` for SwiftUI previews.
- `Services/` — network/IO layer:
  - `SuwayomiService` — `actor`-based REST client for catalog/metadata (`URLSession` + `Codable`).
  - `DownloadManager` — `actor` that builds Nginx URLs for `.cbz` archives, downloads them,
    extracts pages with ZIPFoundation, and will own local cache eviction.
- `ViewModels/` — `@MainActor` view models (not yet implemented).
- `Views/` — SwiftUI views. `RootView`/`ContentView` are placeholders pending the real UI.
- `Utilities/` — `AppConfig` (server endpoints), `ImageDownsampler` (ImageIO-based downsampling
  helper for tall manhwa pages, complementing Kingfisher's downsampling processor).
- `Core/` — reserved for app-wide DI/state (e.g. a future `AppState`) as the app grows.

### Concurrency Model

- `SuwayomiService` and `DownloadManager` are `actor`s so a shared `URLSession` can be used safely
  from concurrent callers.
- ViewModels should be `@MainActor` with `@Published` properties (project default actor isolation
  is `MainActor`; see `SWIFT_DEFAULT_ACTOR_ISOLATION` in build settings).

### Project File Notes

- The Xcode project uses a **file-system-synchronized group** (`PBXFileSystemSynchronizedRootGroup`)
  for `manga-shark/` — any Swift file added under that folder is automatically part of the target,
  no `project.pbxproj` edits required for source files.
- Adding a new SPM package *does* require editing `project.pbxproj`
  (`XCRemoteSwiftPackageReference` + `XCSwiftPackageProductDependency` + `PBXBuildFile` +
  `packageReferences`/`packageProductDependencies`).

### Networking / ATS

`Info.plist` currently only sets `NSAllowsLocalNetworking`. If the Suwayomi or Nginx hosts are
reached over plain HTTP on a non-`.local` hostname/IP, an `NSExceptionDomains` entry (or, for
development only, `NSAllowsArbitraryLoads`) will be needed in `Info.plist`.

## Key Files

- `manga_sharkApp.swift` — App entry point, shows `RootView`.
- `Utilities/AppConfig.swift` — Suwayomi + Nginx/CBZ server base URLs.
- `Services/SuwayomiService.swift` — Suwayomi REST metadata client.
- `Services/DownloadManager.swift` — `.cbz` download, extraction, and cache.
- `Models/Manga.swift`, `Models/Chapter.swift`, `Models/Source.swift` — REST response models.
