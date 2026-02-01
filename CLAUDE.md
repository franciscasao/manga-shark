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

**Dependencies**: Kingfisher (via SPM) for image loading/caching. Requires Xcode 16.2+.

## Architecture

SwiftUI manga reader app following **Clean Architecture with MVVM**:

### Layer Structure
- **Domain** (`Domain/`): Pure data models (Manga, Chapter, Page, Category, Source)
- **Data** (`Data/`): Network, repositories, local storage
- **Presentation** (`Presentation/`): SwiftUI views and ViewModels
- **Core** (`Core/`): DI (AppState), extensions, utilities

### Concurrency Model
Uses Swift Actors throughout for thread safety:
- `NetworkClient` - actor for HTTP/GraphQL communication
- `AuthManager` - @MainActor for auth state
- Repositories (`MangaRepository`, `LibraryRepository`, `ChapterRepository`) - actors with in-memory caching
- `CoreDataStack` - actor for local persistence
- ViewModels - all marked `@MainActor` with `@Published` properties

### Data Flow
1. Views observe ViewModels (`@StateObject`)
2. ViewModels call repository methods (async/await)
3. Repositories execute GraphQL via NetworkClient
4. Response nodes map to domain models via `toDomain()` extensions

### Key Patterns
- **GraphQL**: All network operations in `GraphQLQueries.swift` (queries and mutations)
- **Per-device progress**: Reading progress tracked locally per device and synced to server
- **Two-phase saving**: Local save first, then async server sync
- **AppState singleton**: Global state (server config, tab selection) via `@EnvironmentObject`

### iOS 16/17 Compatibility
- **iOS 17+**: SwiftData for persistence (`@Model`, `@Query`, `ModelContainer`)
- **iOS 16**: UserDefaults/CoreData fallback with wrapper classes
- Pattern: Views check `#available(iOS 17, *)` and delegate to version-specific implementations (e.g., `HistoryViewiOS17` vs `HistoryViewLegacy`)
- SwiftData models in `Data/Local/SwiftData/` use `@available(iOS 17, *)` annotation

### Storage Strategy
- **Keychain**: Server credentials (via KeychainHelper)
- **UserDefaults**: Preferences (reader mode, reading direction, device ID)
- **SwiftData/CoreData**: Device-specific chapter progress, reading history
- **In-memory**: Repository-level caching for manga, library, categories

### Reader Architecture
Two reader modes in `Presentation/Screens/Reader/`:
- **Paged**: Standard page-by-page reading (`PagedReaderView`)
- **Webtoon/Manhwa**: Infinite vertical scroll using UIKit (`ManhwaReaderViewController` wrapped in `ManhwaReaderRepresentable`)

## Key Files

- `manga_sharkApp.swift` - App entry, RootView routing
- `Core/DI/AppState.swift` - Global state management
- `Data/Network/GraphQL/GraphQLQueries.swift` - All GraphQL operations
- `Data/Network/GraphQL/NetworkClient.swift` - HTTP client actor
- `Data/Local/SwiftData/SwiftDataStack.swift` - SwiftData container setup (iOS 17+)
- `Data/Local/Database/CoreDataStack.swift` - Core Data setup (iOS 16 fallback)
- `Presentation/Screens/Reader/ReaderView.swift` - Main reading feature
