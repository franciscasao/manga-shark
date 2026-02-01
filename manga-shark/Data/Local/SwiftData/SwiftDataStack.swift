import Foundation
import SwiftData

actor SwiftDataStack {
    static let shared = SwiftDataStack()

    private var _container: ModelContainer?

    private init() {}

    var container: ModelContainer {
        get throws {
            if let existing = _container {
                return existing
            }

            let schema = Schema([ChapterProgress.self, MangaScanlatorFilter.self])
            let configuration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .automatic
            )

            let container = try ModelContainer(for: schema, configurations: [configuration])
            _container = container
            return container
        }
    }

    func initialize() throws -> ModelContainer {
        return try container
    }
}
