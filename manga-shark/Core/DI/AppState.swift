import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isServerConfigured: Bool = false
    @Published var selectedTab: Tab = .library

    enum Tab: Int, CaseIterable {
        case library
        case browse
        case downloads
        case settings

        var title: String {
            switch self {
            case .library: return "Library"
            case .browse: return "Browse"
            case .downloads: return "Downloads"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .library: return "books.vertical"
            case .browse: return "globe"
            case .downloads: return "arrow.down.circle"
            case .settings: return "gearshape"
            }
        }
    }

    private init() {
        isServerConfigured = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasCompletedSetup)
    }

    func completeSetup() {
        isServerConfigured = true
    }

    func resetSetup() {
        isServerConfigured = false
    }
}
