import Foundation
import SwiftData

// MARK: - iOS 17+ Implementation

@available(iOS 17, *)
@MainActor
final class ScanlatorFilterManageriOS17 {
    static let shared = ScanlatorFilterManageriOS17()

    private var modelContainer: ModelContainer?

    private init() {}

    // MARK: - Configuration

    func configure(with container: ModelContainer) {
        self.modelContainer = container
    }

    // MARK: - Filter Operations

    func getFilter(for mangaId: String) async -> Set<String> {
        guard let container = modelContainer else { return [] }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<MangaScanlatorFilter>(
            predicate: #Predicate { $0.mangaId == mangaId }
        )

        do {
            let results = try context.fetch(descriptor)
            if let filter = results.first {
                return Set(filter.selectedScanlators)
            }
        } catch {
            print("⚠️ [ScanlatorFilterManager] Failed to fetch filter for manga \(mangaId): \(error)")
        }

        return []
    }

    func saveFilter(mangaId: String, scanlators: Set<String>) async {
        guard let container = modelContainer else { return }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<MangaScanlatorFilter>(
            predicate: #Predicate { $0.mangaId == mangaId }
        )

        do {
            let results = try context.fetch(descriptor)
            let now = Date()

            if let existingFilter = results.first {
                existingFilter.selectedScanlators = Array(scanlators)
                existingFilter.updatedAt = now
            } else {
                let newFilter = MangaScanlatorFilter(
                    mangaId: mangaId,
                    selectedScanlators: Array(scanlators),
                    updatedAt: now
                )
                context.insert(newFilter)
            }

            try context.save()
            print("✅ [ScanlatorFilterManager] Filter saved for manga \(mangaId): \(scanlators.count) scanlators")
        } catch {
            print("⚠️ [ScanlatorFilterManager] Failed to save filter for manga \(mangaId): \(error)")
        }
    }

    func clearFilter(mangaId: String) async {
        guard let container = modelContainer else { return }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<MangaScanlatorFilter>(
            predicate: #Predicate { $0.mangaId == mangaId }
        )

        do {
            let results = try context.fetch(descriptor)
            for filter in results {
                context.delete(filter)
            }
            try context.save()
            print("✅ [ScanlatorFilterManager] Filter cleared for manga \(mangaId)")
        } catch {
            print("⚠️ [ScanlatorFilterManager] Failed to clear filter for manga \(mangaId): \(error)")
        }
    }

    func getAllFilters() async -> [String: Set<String>] {
        guard let container = modelContainer else { return [:] }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<MangaScanlatorFilter>()

        do {
            let results = try context.fetch(descriptor)
            var filters: [String: Set<String>] = [:]
            for filter in results {
                if !filter.selectedScanlators.isEmpty {
                    filters[filter.mangaId] = Set(filter.selectedScanlators)
                }
            }
            return filters
        } catch {
            print("⚠️ [ScanlatorFilterManager] Failed to fetch all filters: \(error)")
            return [:]
        }
    }
}

// MARK: - iOS 16 Fallback (UserDefaults)

private struct ScanlatorFilterStorageiOS16 {
    private static let userDefaultsKey = "manga_scanlator_filters"

    static func getFilter(for mangaId: String) -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let filters = try? JSONDecoder().decode([String: [String]].self, from: data),
              let scanlators = filters[mangaId] else {
            return []
        }
        return Set(scanlators)
    }

    static func saveFilter(mangaId: String, scanlators: Set<String>) {
        var filters = getAllFiltersDict()

        if scanlators.isEmpty {
            filters.removeValue(forKey: mangaId)
        } else {
            filters[mangaId] = Array(scanlators)
        }

        if let data = try? JSONEncoder().encode(filters) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    static func clearFilter(mangaId: String) {
        var filters = getAllFiltersDict()
        filters.removeValue(forKey: mangaId)

        if let data = try? JSONEncoder().encode(filters) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    static func getAllFilters() -> [String: Set<String>] {
        let dict = getAllFiltersDict()
        return dict.mapValues { Set($0) }
    }

    private static func getAllFiltersDict() -> [String: [String]] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let filters = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return filters
    }
}

// MARK: - Cross-Platform Wrapper

@MainActor
final class ScanlatorFilterManager {
    static let shared = ScanlatorFilterManager()

    private init() {}

    // MARK: - Configuration

    @available(iOS 17, *)
    func configure(with container: ModelContainer) {
        ScanlatorFilterManageriOS17.shared.configure(with: container)
    }

    // MARK: - Filter Operations

    func getFilter(for mangaId: String) async -> Set<String> {
        if #available(iOS 17, *) {
            return await ScanlatorFilterManageriOS17.shared.getFilter(for: mangaId)
        } else {
            return ScanlatorFilterStorageiOS16.getFilter(for: mangaId)
        }
    }

    func saveFilter(mangaId: String, scanlators: Set<String>) async {
        if #available(iOS 17, *) {
            await ScanlatorFilterManageriOS17.shared.saveFilter(mangaId: mangaId, scanlators: scanlators)
        } else {
            ScanlatorFilterStorageiOS16.saveFilter(mangaId: mangaId, scanlators: scanlators)
        }
    }

    func clearFilter(mangaId: String) async {
        if #available(iOS 17, *) {
            await ScanlatorFilterManageriOS17.shared.clearFilter(mangaId: mangaId)
        } else {
            ScanlatorFilterStorageiOS16.clearFilter(mangaId: mangaId)
        }
    }

    func getAllFilters() async -> [String: Set<String>] {
        if #available(iOS 17, *) {
            return await ScanlatorFilterManageriOS17.shared.getAllFilters()
        } else {
            return ScanlatorFilterStorageiOS16.getAllFilters()
        }
    }
}
