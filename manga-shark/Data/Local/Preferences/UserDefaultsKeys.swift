import Foundation

enum UserDefaultsKeys {
    static let serverUrl = "server_url"
    static let authType = "auth_type"
    static let hasCompletedSetup = "has_completed_setup"
    static let readerMode = "reader_mode"
    static let readerDirection = "reader_direction"
    static let libraryDisplayMode = "library_display_mode"
    static let librarySortOrder = "library_sort_order"
    static let librarySortAscending = "library_sort_ascending"
    static let selectedCategoryId = "selected_category_id"
    static let showNsfwSources = "show_nsfw_sources"
}

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    let container: UserDefaults = .standard

    var wrappedValue: T {
        get {
            container.object(forKey: key) as? T ?? defaultValue
        }
        set {
            container.set(newValue, forKey: key)
        }
    }
}

@propertyWrapper
struct CodableUserDefault<T: Codable> {
    let key: String
    let defaultValue: T
    let container: UserDefaults = .standard

    var wrappedValue: T {
        get {
            guard let data = container.data(forKey: key),
                  let value = try? JSONDecoder().decode(T.self, from: data) else {
                return defaultValue
            }
            return value
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                container.set(data, forKey: key)
            }
        }
    }
}
