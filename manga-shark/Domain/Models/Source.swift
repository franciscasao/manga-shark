import Foundation

struct Source: Identifiable, Hashable {
    let id: String
    let name: String
    let lang: String
    let iconUrl: String?
    let supportsLatest: Bool
    let isConfigurable: Bool
    let isNsfw: Bool
    let displayName: String

    init(
        id: String,
        name: String,
        lang: String,
        iconUrl: String? = nil,
        supportsLatest: Bool = true,
        isConfigurable: Bool = false,
        isNsfw: Bool = false,
        displayName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.lang = lang
        self.iconUrl = iconUrl
        self.supportsLatest = supportsLatest
        self.isConfigurable = isConfigurable
        self.isNsfw = isNsfw
        self.displayName = displayName ?? name
    }
}

extension Source {
    var languageDisplayName: String {
        let locale = Locale.current
        return locale.localizedString(forLanguageCode: lang) ?? lang.uppercased()
    }
}

struct SourceFilter: Identifiable {
    let id = UUID()
    let name: String
    let type: FilterType
    var state: FilterState

    enum FilterType {
        case header
        case separator
        case text
        case checkBox
        case triState
        case sort
        case select
        case group
    }

    enum FilterState {
        case none
        case text(String)
        case boolean(Bool)
        case triState(TriState)
        case selection(Int)
        case sort(SortState)
        case group([SourceFilter])
    }

    enum TriState {
        case ignore
        case include
        case exclude
    }

    struct SortState {
        let index: Int
        let ascending: Bool
    }
}
