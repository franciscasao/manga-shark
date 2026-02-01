import Foundation
import SwiftData

// MARK: - Scanlator Filter Manager

@MainActor
final class ScanlatorFilterManager {
    static let shared = ScanlatorFilterManager()

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
