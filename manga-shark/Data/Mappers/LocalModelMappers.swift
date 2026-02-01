import Foundation
import SwiftData

// MARK: - Manga -> LocalManga (for saving)

extension Manga {
    func toLocalManga() -> LocalManga {
        LocalManga(
            serverId: id,
            sourceId: sourceId,
            url: url,
            title: title,
            thumbnailUrl: thumbnailUrl,
            artist: artist,
            author: author,
            descriptionText: description,
            genres: genre,
            status: status.rawValue,
            addedToLibraryAt: Date(),
            lastRefreshedAt: lastFetchedAt
        )
    }
}

// MARK: - LocalManga -> Manga (for display)

extension LocalManga {
    func toDomain(chapters: [Chapter] = [], deviceUnreadCount: Int = 0) -> Manga {
        Manga(
            id: serverId,
            sourceId: sourceId,
            url: url,
            title: title,
            thumbnailUrl: thumbnailUrl,
            artist: artist,
            author: author,
            description: descriptionText,
            genre: genres,
            status: MangaStatus(rawValue: status) ?? .unknown,
            inLibrary: true,
            inLibraryAt: addedToLibraryAt,
            lastFetchedAt: lastRefreshedAt,
            unreadCount: deviceUnreadCount,
            chapterCount: self.chapters.count
        )
    }
}

// MARK: - Chapter -> LocalChapter (for saving)

extension Chapter {
    func toLocalChapter() -> LocalChapter {
        LocalChapter(
            serverId: id,
            url: url,
            name: name,
            scanlator: scanlator,
            chapterNumber: chapterNumber,
            sourceOrder: sourceOrder,
            uploadDate: uploadDate,
            pageCount: pageCount,
            addedAt: Date()
        )
    }
}

// MARK: - LocalChapter -> Chapter (for display)

extension LocalChapter {
    func toDomain(mangaId: Int, isRead: Bool = false) -> Chapter {
        Chapter(
            id: serverId,
            mangaId: mangaId,
            url: url,
            name: name,
            scanlator: scanlator,
            chapterNumber: chapterNumber,
            sourceOrder: sourceOrder,
            uploadDate: uploadDate,
            isRead: isRead,
            pageCount: pageCount
        )
    }
}
