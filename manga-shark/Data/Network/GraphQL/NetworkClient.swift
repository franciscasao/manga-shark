import Foundation

actor NetworkClient {
    static let shared = NetworkClient()

    private var session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    func executeGraphQL<T: Decodable>(
        query: String,
        variables: [String: Any]? = nil,
        responseType: T.Type
    ) async throws -> T {
        let authManager = await AuthManager.shared
        let serverConfig = await authManager.serverConfig

        guard let url = URL(string: serverConfig.graphqlUrl) else {
            throw NetworkError.invalidUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let authHeader = await authManager.authorizationHeader {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }

        var body: [String: Any] = ["query": query]
        if let variables = variables {
            body["variables"] = variables
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw NetworkError.unauthorized
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let timestamp = try container.decode(Int64.self)
            return Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        }

        return try decoder.decode(T.self, from: data)
    }

    func fetchImage(from urlString: String) async throws -> Data {
        let authManager = await AuthManager.shared
        let serverConfig = await authManager.serverConfig

        var fullUrl = urlString
        if urlString.hasPrefix("/") {
            fullUrl = serverConfig.serverUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + urlString
        }

        guard let url = URL(string: fullUrl) else {
            throw NetworkError.invalidUrl
        }

        var request = URLRequest(url: url)
        if let authHeader = await authManager.authorizationHeader {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        return data
    }
}

enum NetworkError: Error, LocalizedError {
    case invalidUrl
    case invalidResponse
    case httpError(Int)
    case unauthorized
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .unauthorized:
            return "Unauthorized. Please check your credentials."
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
