import Foundation

// MARK: - Base Response

struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLError]?
}

struct GraphQLError: Decodable {
    let message: String
    let locations: [ErrorLocation]?
    let path: [String]?

    struct ErrorLocation: Decodable {
        let line: Int
        let column: Int
    }
}

// MARK: - Sources

struct SourcesResponse: Decodable {
    let sources: SourcesConnection
}

struct SourcesConnection: Decodable {
    let nodes: [SourceNode]
}

struct SourceNode: Decodable {
    let id: String
    let name: String
    let lang: String
    let iconUrl: String?
    let supportsLatest: Bool
    let isConfigurable: Bool
    let isNsfw: Bool
    let displayName: String?
}

// MARK: - Manga List

struct FetchSourceMangaResponse: Decodable {
    let fetchSourceManga: SourceMangaResult
}

struct SourceMangaResult: Decodable {
    let hasNextPage: Bool
    let mangas: [MangaNode]
}

struct MangaNode: Decodable {
    let id: Int
    let sourceId: String
    let url: String
    let title: String
    let thumbnailUrl: String?
    let artist: String?
    let author: String?
    let description: String?
    let genre: [String]?
    let status: String?
    let inLibrary: Bool?
    let inLibraryAt: Int64?
    let realUrl: String?
    let lastFetchedAt: Int64?
    let chaptersLastFetchedAt: Int64?
    let updateStrategy: String?
    let freshData: Bool?
    let unreadCount: Int?
    let downloadCount: Int?
    let chapterCount: Int?
    let chapters: ChaptersConnection?
    let categories: CategoriesConnection?
}

// MARK: - Single Manga

struct MangaResponse: Decodable {
    let manga: MangaNode
}

// MARK: - Chapters

struct ChaptersConnection: Decodable {
    let nodes: [ChapterNode]
}

struct ChapterNode: Decodable {
    let id: Int
    let mangaId: Int
    let url: String
    let name: String
    let scanlator: String?
    let chapterNumber: Double
    let sourceOrder: Int
    let uploadDate: Int64?
    let isRead: Bool
    let isBookmarked: Bool
    let isDownloaded: Bool
    let lastPageRead: Int
    let pageCount: Int
    let realUrl: String?
    let fetchedAt: Int64?
}

struct FetchChaptersResponse: Decodable {
    let fetchChapters: FetchChaptersResult
}

struct FetchChaptersResult: Decodable {
    let chapters: [ChapterNode]
}

// MARK: - Chapter Pages

struct ChapterPagesResponse: Decodable {
    let chapter: ChapterNode
    let fetchChapterPages: FetchPagesResult
}

struct FetchPagesResult: Decodable {
    let pages: [String]
}

// MARK: - Library

struct LibraryResponse: Decodable {
    let mangas: MangasConnection
}

struct MangasConnection: Decodable {
    let nodes: [MangaNode]
}

// MARK: - Categories

struct CategoriesResponse: Decodable {
    let categories: CategoriesConnection
}

struct CategoriesConnection: Decodable {
    let nodes: [CategoryNode]
}

struct CategoryNode: Decodable {
    let id: Int
    let name: String
    let order: Int
    let includeInUpdate: String?
    let includeInDownload: String?
    let `default`: Bool?
    let mangas: MangaCount?

    struct MangaCount: Decodable {
        let totalCount: Int?
    }
}

// MARK: - Downloads

struct DownloadStatusResponse: Decodable {
    let downloadStatus: DownloadStatus
}

struct DownloadStatus: Decodable {
    let state: String
    let queue: [DownloadQueueItem]
}

struct DownloadQueueItem: Decodable {
    let chapter: DownloadChapterInfo
    let progress: Double
    let state: String
    let tries: Int
}

struct DownloadChapterInfo: Decodable {
    let id: Int
    let name: String
    let manga: DownloadMangaInfo?
}

struct DownloadMangaInfo: Decodable {
    let id: Int
    let title: String
}

// MARK: - Server Info

struct ServerInfoResponse: Decodable {
    let aboutServer: AboutServer
    let aboutWebUI: AboutWebUI
}

struct AboutServer: Decodable {
    let name: String
    let version: String
    let buildType: String
    let buildTime: String
    let github: String
    let discord: String
}

struct AboutWebUI: Decodable {
    let channel: String
    let tag: String
}

// MARK: - Mutations

struct UpdateMangaResponse: Decodable {
    let updateManga: UpdateMangaResult
}

struct UpdateMangaResult: Decodable {
    let manga: MangaNode
}

struct UpdateChapterResponse: Decodable {
    let updateChapter: UpdateChapterResult
}

struct UpdateChapterResult: Decodable {
    let chapter: ChapterNode
}

struct UpdateChaptersResponse: Decodable {
    let updateChapters: UpdateChaptersResult
}

struct UpdateChaptersResult: Decodable {
    let chapters: [ChapterNode]
}
