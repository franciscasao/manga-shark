import Foundation

enum GraphQLQueries {

    // MARK: - Sources

    static let getSources = """
    query GetSources {
        sources {
            nodes {
                id
                name
                lang
                iconUrl
                supportsLatest
                isConfigurable
                isNsfw
                displayName
            }
        }
    }
    """

    static let getSourceManga = """
    query GetSourceManga($sourceId: LongString!, $type: FetchSourceMangaType!, $page: Int!) {
        fetchSourceManga(input: { source: $sourceId, type: $type, page: $page }) {
            hasNextPage
            mangas {
                id
                sourceId
                url
                title
                thumbnailUrl
                artist
                author
                description
                genre
                status
                inLibrary
            }
        }
    }
    """

    static let searchSource = """
    query SearchSource($sourceId: LongString!, $query: String!, $page: Int!) {
        fetchSourceManga(input: { source: $sourceId, type: SEARCH, page: $page, query: $query }) {
            hasNextPage
            mangas {
                id
                sourceId
                url
                title
                thumbnailUrl
                artist
                author
                description
                genre
                status
                inLibrary
            }
        }
    }
    """

    // MARK: - Manga

    static let getManga = """
    query GetManga($id: Int!) {
        manga(id: $id) {
            id
            sourceId
            url
            title
            thumbnailUrl
            artist
            author
            description
            genre
            status
            inLibrary
            inLibraryAt
            realUrl
            lastFetchedAt
            chaptersLastFetchedAt
            updateStrategy
            freshData
            unreadCount
            downloadCount
            chapterCount
            chapters {
                nodes {
                    id
                    mangaId
                    url
                    name
                    scanlator
                    chapterNumber
                    sourceOrder
                    uploadDate
                    isRead
                    isBookmarked
                    isDownloaded
                    lastPageRead
                    pageCount
                    realUrl
                    fetchedAt
                }
            }
            categories {
                nodes {
                    id
                    name
                    order
                }
            }
        }
    }
    """

    static let fetchChapters = """
    mutation FetchChapters($mangaId: Int!) {
        fetchChapters(input: { mangaId: $mangaId }) {
            chapters {
                id
                mangaId
                url
                name
                scanlator
                chapterNumber
                sourceOrder
                uploadDate
                isRead
                isBookmarked
                isDownloaded
                lastPageRead
                pageCount
            }
        }
    }
    """

    // MARK: - Library

    static let getLibrary = """
    query GetLibrary {
        mangas(condition: { inLibrary: true }) {
            nodes {
                id
                sourceId
                url
                title
                thumbnailUrl
                artist
                author
                description
                genre
                status
                inLibrary
                unreadCount
                downloadCount
                chapterCount
                categories {
                    nodes {
                        id
                        name
                    }
                }
            }
        }
    }
    """

    static let updateMangaLibrary = """
    mutation UpdateMangaLibrary($id: Int!, $inLibrary: Boolean!) {
        updateManga(input: { id: $id, patch: { inLibrary: $inLibrary } }) {
            manga {
                id
                inLibrary
            }
        }
    }
    """

    // MARK: - Categories

    static let getCategories = """
    query GetCategories {
        categories {
            nodes {
                id
                name
                order
                includeInUpdate
                includeInDownload
                default
                mangas {
                    totalCount
                }
            }
        }
    }
    """

    static let createCategory = """
    mutation CreateCategory($name: String!) {
        createCategory(input: { name: $name }) {
            category {
                id
                name
                order
            }
        }
    }
    """

    static let updateMangaCategories = """
    mutation UpdateMangaCategories($mangaId: Int!, $categoryIds: [Int!]!) {
        updateMangaCategories(input: { id: $mangaId, patch: { addToCategories: $categoryIds, clearCategories: true } }) {
            manga {
                id
                categories {
                    nodes {
                        id
                        name
                    }
                }
            }
        }
    }
    """

    // MARK: - Chapters

    static let getChapterPages = """
    query GetChapterPages($chapterId: Int!) {
        chapter(id: $chapterId) {
            id
            mangaId
            pageCount
            name
            chapterNumber
        }
        fetchChapterPages(input: { chapterId: $chapterId }) {
            pages
        }
    }
    """

    static let updateChapterProgress = """
    mutation UpdateChapterProgress($chapterId: Int!, $lastPageRead: Int!, $isRead: Boolean!) {
        updateChapter(input: { id: $chapterId, patch: { lastPageRead: $lastPageRead, isRead: $isRead } }) {
            chapter {
                id
                lastPageRead
                isRead
            }
        }
    }
    """

    static let markChaptersRead = """
    mutation MarkChaptersRead($chapterIds: [Int!]!, $isRead: Boolean!) {
        updateChapters(input: { ids: $chapterIds, patch: { isRead: $isRead } }) {
            chapters {
                id
                isRead
            }
        }
    }
    """

    // MARK: - Downloads

    static let getDownloadQueue = """
    query GetDownloadQueue {
        downloadStatus {
            state
            queue {
                chapter {
                    id
                    name
                    manga {
                        id
                        title
                    }
                }
                progress
                state
                tries
            }
        }
    }
    """

    static let enqueueDownload = """
    mutation EnqueueDownload($chapterIds: [Int!]!) {
        enqueueChapterDownloads(input: { ids: $chapterIds }) {
            downloadStatus {
                state
                queue {
                    chapter {
                        id
                    }
                    state
                }
            }
        }
    }
    """

    static let deleteDownloadedChapter = """
    mutation DeleteDownloadedChapter($chapterId: Int!) {
        deleteDownloadedChapter(input: { id: $chapterId }) {
            chapters {
                id
                isDownloaded
            }
        }
    }
    """

    static let startDownloader = """
    mutation StartDownloader {
        startDownloader(input: {}) {
            downloadStatus {
                state
            }
        }
    }
    """

    static let stopDownloader = """
    mutation StopDownloader {
        stopDownloader(input: {}) {
            downloadStatus {
                state
            }
        }
    }
    """

    static let clearDownloadQueue = """
    mutation ClearDownloadQueue {
        clearDownloader(input: {}) {
            downloadStatus {
                state
                queue {
                    chapter {
                        id
                    }
                }
            }
        }
    }
    """

    // MARK: - Global Search

    static let globalSearch = """
    query GlobalSearch($query: String!) {
        fetchSourceManga(input: { source: "all", type: SEARCH, query: $query, page: 1 }) {
            mangas {
                id
                sourceId
                url
                title
                thumbnailUrl
                inLibrary
            }
        }
    }
    """

    // MARK: - Server Info

    static let getServerInfo = """
    query GetServerInfo {
        aboutServer {
            name
            version
            buildType
            buildTime
            github
            discord
        }
        aboutWebUI {
            channel
            tag
        }
    }
    """
}
