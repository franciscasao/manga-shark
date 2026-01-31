import Foundation
import UIKit
import Kingfisher

struct AuthenticatedRequestModifier: AsyncImageDownloadRequestModifier {
    let serverUrl: String
    let authHeader: String?

    var onDownloadTaskStarted: (@Sendable (DownloadTask?) -> Void)? { nil }

    init(serverUrl: String, authHeader: String?) {
        self.serverUrl = serverUrl
        self.authHeader = authHeader
    }

    func modified(for request: URLRequest) async -> URLRequest? {
        var modifiedRequest = request

        // Handle relative URLs
        if let url = request.url, url.host == nil || url.scheme == nil {
            let baseUrl = serverUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let path = url.absoluteString
            if let fullUrl = URL(string: baseUrl + (path.hasPrefix("/") ? path : "/" + path)) {
                modifiedRequest.url = fullUrl
            }
        }

        // Add authorization header
        if let authHeader = authHeader {
            modifiedRequest.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }

        return modifiedRequest
    }
}

struct ManhwaImageOptions {
    static func defaultOptions(screenWidth: CGFloat, serverUrl: String, authHeader: String?) -> KingfisherOptionsInfo {
        let scale = UIScreen.main.scale
        let downsampleSize = CGSize(
            width: screenWidth * scale,
            height: 10000
        )

        return [
            .requestModifier(AuthenticatedRequestModifier(serverUrl: serverUrl, authHeader: authHeader)),
            .processor(DownsamplingImageProcessor(size: downsampleSize)),
            .scaleFactor(scale),
            .cacheOriginalImage,
            .backgroundDecode,
            .transition(.fade(0.2))
        ]
    }

    static func prefetchOptions(screenWidth: CGFloat, serverUrl: String, authHeader: String?) -> KingfisherOptionsInfo {
        let scale = UIScreen.main.scale
        let downsampleSize = CGSize(
            width: screenWidth * scale,
            height: 10000
        )

        return [
            .requestModifier(AuthenticatedRequestModifier(serverUrl: serverUrl, authHeader: authHeader)),
            .processor(DownsamplingImageProcessor(size: downsampleSize)),
            .scaleFactor(scale),
            .cacheOriginalImage,
            .backgroundDecode
        ]
    }
}

extension String {
    func toManhwaImageURL(serverUrl: String) -> URL? {
        if self.hasPrefix("http://") || self.hasPrefix("https://") {
            return URL(string: self)
        }

        let baseUrl = serverUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let path = self.hasPrefix("/") ? self : "/" + self
        return URL(string: baseUrl + path)
    }
}
