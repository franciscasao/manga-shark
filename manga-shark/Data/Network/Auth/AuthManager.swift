import Foundation
import Combine

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var serverConfig: ServerConfig
    @Published private(set) var isConfigured: Bool

    private let userDefaults = UserDefaults.standard

    private init() {
        let serverUrl = userDefaults.string(forKey: UserDefaultsKeys.serverUrl) ?? ""
        let authTypeRaw = userDefaults.string(forKey: UserDefaultsKeys.authType) ?? ServerConfig.AuthType.none.rawValue
        let authType = ServerConfig.AuthType(rawValue: authTypeRaw) ?? .none

        self.serverConfig = ServerConfig(
            serverUrl: serverUrl,
            authType: authType
        )
        self.isConfigured = userDefaults.bool(forKey: UserDefaultsKeys.hasCompletedSetup)

        Task {
            await loadCredentials()
        }
    }

    private func loadCredentials() async {
        if serverConfig.authType == .basic {
            if let credentials = await KeychainHelper.shared.getCredentials() {
                serverConfig.username = credentials.username
                serverConfig.password = credentials.password
            }
        }
    }

    func configure(with config: ServerConfig) async throws {
        userDefaults.set(config.serverUrl, forKey: UserDefaultsKeys.serverUrl)
        userDefaults.set(config.authType.rawValue, forKey: UserDefaultsKeys.authType)

        if config.authType == .basic,
           let username = config.username,
           let password = config.password {
            try await KeychainHelper.shared.saveCredentials(username: username, password: password)
        } else {
            await KeychainHelper.shared.deleteCredentials()
        }

        userDefaults.set(true, forKey: UserDefaultsKeys.hasCompletedSetup)

        self.serverConfig = config
        self.isConfigured = true
    }

    func testConnection() async throws -> Bool {
        guard serverConfig.isValid else {
            throw AuthError.invalidConfiguration
        }

        guard let url = URL(string: serverConfig.graphqlUrl) else {
            throw AuthError.invalidUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if serverConfig.authType == .basic,
           let username = serverConfig.username,
           let password = serverConfig.password {
            let credentials = "\(username):\(password)"
            if let credentialsData = credentials.data(using: .utf8) {
                let base64Credentials = credentialsData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }

        let query = """
        {"query": "{ __typename }"}
        """
        request.httpBody = query.data(using: .utf8)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return true
        case 401:
            throw AuthError.unauthorized
        case 403:
            throw AuthError.forbidden
        default:
            throw AuthError.serverError(httpResponse.statusCode)
        }
    }

    func clearConfiguration() async {
        userDefaults.removeObject(forKey: UserDefaultsKeys.serverUrl)
        userDefaults.removeObject(forKey: UserDefaultsKeys.authType)
        userDefaults.removeObject(forKey: UserDefaultsKeys.hasCompletedSetup)
        await KeychainHelper.shared.deleteCredentials()

        self.serverConfig = ServerConfig()
        self.isConfigured = false
    }

    var authorizationHeader: String? {
        guard serverConfig.authType == .basic,
              let username = serverConfig.username,
              let password = serverConfig.password else {
            return nil
        }

        let credentials = "\(username):\(password)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            return nil
        }

        return "Basic \(credentialsData.base64EncodedString())"
    }
}

enum AuthError: Error, LocalizedError {
    case invalidConfiguration
    case invalidUrl
    case invalidResponse
    case unauthorized
    case forbidden
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid server configuration"
        case .invalidUrl:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Authentication failed. Check your credentials."
        case .forbidden:
            return "Access denied"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}
