# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the project
xcodebuild -project manga-shark.xcodeproj -scheme manga-shark build

# Build for simulator
xcodebuild -project manga-shark.xcodeproj -scheme manga-shark -destination 'platform=iOS Simulator,name=iPhone 16'

# Clean build
xcodebuild -project manga-shark.xcodeproj -scheme manga-shark clean build
```

No external dependencies - pure Xcode project with Swift/SwiftUI only. Requires Xcode 16.2+.

## Architecture

This is a SwiftUI manga reader app following **Clean Architecture with MVVM**:

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
- **Per-device progress**: Reading progress tracked locally per device (CoreData) and synced to server
- **Two-phase saving**: Local CoreData save first, then async server sync
- **AppState singleton**: Global state (server config, tab selection) via `@EnvironmentObject`

### Storage Strategy
- **Keychain**: Server credentials (via KeychainHelper)
- **UserDefaults**: Preferences (reader mode, reading direction, device ID)
- **CoreData**: Device-specific chapter progress, cached manga/images
- **In-memory**: Repository-level caching for manga, library, categories

## Key Files

- `manga_sharkApp.swift` - App entry, RootView routing
- `Core/DI/AppState.swift` - Global state management
- `Data/Network/GraphQL/GraphQLQueries.swift` - All GraphQL operations
- `Data/Network/GraphQL/NetworkClient.swift` - HTTP client actor
- `Data/Local/Database/CoreDataStack.swift` - Core Data setup (programmatic model)
- `Presentation/Screens/Reader/ReaderView.swift` - Main reading feature
