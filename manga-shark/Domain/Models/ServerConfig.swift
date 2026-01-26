import Foundation

struct ServerConfig: Codable, Equatable {
    var serverUrl: String
    var authType: AuthType
    var username: String?
    var password: String?

    init(
        serverUrl: String = "",
        authType: AuthType = .none,
        username: String? = nil,
        password: String? = nil
    ) {
        self.serverUrl = serverUrl
        self.authType = authType
        self.username = username
        self.password = password
    }

    enum AuthType: String, Codable, CaseIterable {
        case none = "none"
        case basic = "basic"

        var displayName: String {
            switch self {
            case .none: return "None"
            case .basic: return "Basic Auth"
            }
        }
    }

    var isValid: Bool {
        guard let url = URL(string: serverUrl),
              url.scheme != nil,
              url.host != nil else {
            return false
        }

        if authType == .basic {
            return !(username?.isEmpty ?? true) && !(password?.isEmpty ?? true)
        }

        return true
    }

    var graphqlUrl: String {
        serverUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/api/graphql"
    }

    var baseUrl: URL? {
        URL(string: serverUrl)
    }
}
