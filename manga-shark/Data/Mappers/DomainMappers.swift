import Foundation

// MARK: - Source Mapping

extension SourceNode {
    func toDomain() -> Source {
        Source(
            id: id,
            name: name,
            lang: lang,
            iconUrl: iconUrl,
            supportsLatest: supportsLatest,
            isConfigurable: isConfigurable,
            isNsfw: isNsfw,
            displayName: displayName
        )
    }
}

// MARK: - Manga Mapping

extension MangaNode {
    func toDomain() -> Manga {
        Manga(
            id: id,
            sourceId: sourceId,
            url: url,
            title: title,
            thumbnailUrl: thumbnailUrl,
            artist: artist,
            author: author,
            description: description,
            genre: genre ?? [],
            status: MangaStatus(rawValue: status ?? "") ?? .unknown,
            inLibrary: inLibrary ?? false,
            inLibraryAt: inLibraryAt.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) },
            realUrl: realUrl,
            lastFetchedAt: lastFetchedAt.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) },
            chaptersLastFetchedAt: chaptersLastFetchedAt.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) },
            updateStrategy: UpdateStrategy(rawValue: updateStrategy ?? "") ?? .alwaysUpdate,
            freshData: freshData ?? false,
            unreadCount: unreadCount ?? 0,
            downloadCount: downloadCount ?? 0,
            chapterCount: chapterCount ?? 0,
            categories: categories?.nodes.map { $0.toDomain() } ?? []
        )
    }
}

// MARK: - Chapter Mapping

extension ChapterNode {
    func toDomain() -> Chapter {
        Chapter(
            id: id,
            mangaId: mangaId,
            url: url,
            name: name,
            scanlator: scanlator,
            chapterNumber: chapterNumber,
            sourceOrder: sourceOrder,
            uploadDate: uploadDate.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) },
            isRead: isRead,
            isBookmarked: isBookmarked,
            isDownloaded: isDownloaded,
            lastPageRead: lastPageRead,
            pageCount: pageCount,
            realUrl: realUrl,
            fetchedAt: fetchedAt.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        )
    }
}

// MARK: - Category Mapping

extension CategoryNode {
    func toDomain() -> Category {
        Category(
            id: id,
            name: name,
            order: order,
            includeInUpdate: Category.IncludeInUpdate(rawValue: includeInUpdate ?? "UNSET") ?? .unset,
            includeInDownload: Category.IncludeInUpdate(rawValue: includeInDownload ?? "UNSET") ?? .unset,
            isDefault: `default` ?? false,
            mangaCount: mangas?.totalCount ?? 0
        )
    }
}
