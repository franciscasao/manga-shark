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
            print("❌ [NetworkClient] Invalid URL: \(serverConfig.graphqlUrl)")
            throw NetworkError.invalidUrl
        }

        // Log request details
        print("🌐 [NetworkClient] GraphQL Request")
        print("🌐 [NetworkClient] URL: \(url)")
        print("🌐 [NetworkClient] Query: \(query.prefix(200))\(query.count > 200 ? "..." : "")")
        if let variables = variables {
            print("🌐 [NetworkClient] Variables: \(variables)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let authHeader = await authManager.authorizationHeader {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
            print("🌐 [NetworkClient] Auth header present: \(authHeader.prefix(20))...")
        } else {
            print("⚠️ [NetworkClient] No auth header")
        }

        var body: [String: Any] = ["query": query]
        if let variables = variables {
            body["variables"] = variables
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [NetworkClient] Invalid response type")
            throw NetworkError.invalidResponse
        }

        print("✅ [NetworkClient] HTTP Response: \(httpResponse.statusCode)")
        print("📦 [NetworkClient] Response size: \(data.count) bytes")

        // Log raw JSON response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📦 [NetworkClient] Raw JSON: \(jsonString)")
        } else {
            print("⚠️ [NetworkClient] Could not convert response to string")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ [NetworkClient] HTTP Error: \(httpResponse.statusCode)")
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

        // Wrap decoding with error handling
        print("🔄 [NetworkClient] Attempting to decode as \(T.self)")
        do {
            let result = try decoder.decode(T.self, from: data)
            print("✅ [NetworkClient] Successfully decoded \(T.self)")
            return result
        } catch let decodingError as DecodingError {
            print("❌ [NetworkClient] Decoding Error: \(decodingError)")
            switch decodingError {
            case .keyNotFound(let key, let context):
                print("❌ [NetworkClient] Key '\(key.stringValue)' not found: \(context.debugDescription)")
                print("❌ [NetworkClient] Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            case .typeMismatch(let type, let context):
                print("❌ [NetworkClient] Type mismatch for type \(type): \(context.debugDescription)")
                print("❌ [NetworkClient] Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            case .valueNotFound(let type, let context):
                print("❌ [NetworkClient] Value not found for type \(type): \(context.debugDescription)")
                print("❌ [NetworkClient] Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            case .dataCorrupted(let context):
                print("❌ [NetworkClient] Data corrupted: \(context.debugDescription)")
                print("❌ [NetworkClient] Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            @unknown default:
                print("❌ [NetworkClient] Unknown decoding error: \(decodingError)")
            }
            throw NetworkError.decodingError(decodingError)
        } catch {
            print("❌ [NetworkClient] Unexpected error during decoding: \(error)")
            throw NetworkError.decodingError(error)
        }
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
