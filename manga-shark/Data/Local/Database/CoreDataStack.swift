import CoreData
import Foundation

actor CoreDataStack {
    static let shared = CoreDataStack()

    private let container: NSPersistentContainer

    private init() {
        // Create the model programmatically since we don't have an xcdatamodeld file
        let model = Self.createManagedObjectModel()
        container = NSPersistentContainer(name: "MangaReader", managedObjectModel: model)

        // Enable lightweight migration for schema changes
        let description = container.persistentStoreDescriptions.first
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }

    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Model Creation

    private static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // CachedManga Entity
        let mangaEntity = NSEntityDescription()
        mangaEntity.name = "CachedManga"
        mangaEntity.managedObjectClassName = "CachedManga"

        let mangaIdAttr = NSAttributeDescription()
        mangaIdAttr.name = "id"
        mangaIdAttr.attributeType = .integer32AttributeType

        let mangaTitleAttr = NSAttributeDescription()
        mangaTitleAttr.name = "title"
        mangaTitleAttr.attributeType = .stringAttributeType

        let mangaSourceIdAttr = NSAttributeDescription()
        mangaSourceIdAttr.name = "sourceId"
        mangaSourceIdAttr.attributeType = .stringAttributeType

        let mangaUrlAttr = NSAttributeDescription()
        mangaUrlAttr.name = "url"
        mangaUrlAttr.attributeType = .stringAttributeType

        let mangaThumbnailAttr = NSAttributeDescription()
        mangaThumbnailAttr.name = "thumbnailUrl"
        mangaThumbnailAttr.attributeType = .stringAttributeType
        mangaThumbnailAttr.isOptional = true

        let mangaAuthorAttr = NSAttributeDescription()
        mangaAuthorAttr.name = "author"
        mangaAuthorAttr.attributeType = .stringAttributeType
        mangaAuthorAttr.isOptional = true

        let mangaArtistAttr = NSAttributeDescription()
        mangaArtistAttr.name = "artist"
        mangaArtistAttr.attributeType = .stringAttributeType
        mangaArtistAttr.isOptional = true

        let mangaDescAttr = NSAttributeDescription()
        mangaDescAttr.name = "mangaDescription"
        mangaDescAttr.attributeType = .stringAttributeType
        mangaDescAttr.isOptional = true

        let mangaStatusAttr = NSAttributeDescription()
        mangaStatusAttr.name = "status"
        mangaStatusAttr.attributeType = .stringAttributeType

        let mangaInLibraryAttr = NSAttributeDescription()
        mangaInLibraryAttr.name = "inLibrary"
        mangaInLibraryAttr.attributeType = .booleanAttributeType

        let mangaLastUpdatedAttr = NSAttributeDescription()
        mangaLastUpdatedAttr.name = "lastUpdated"
        mangaLastUpdatedAttr.attributeType = .dateAttributeType

        let mangaGenreAttr = NSAttributeDescription()
        mangaGenreAttr.name = "genreData"
        mangaGenreAttr.attributeType = .binaryDataAttributeType
        mangaGenreAttr.isOptional = true

        mangaEntity.properties = [
            mangaIdAttr, mangaTitleAttr, mangaSourceIdAttr, mangaUrlAttr,
            mangaThumbnailAttr, mangaAuthorAttr, mangaArtistAttr, mangaDescAttr,
            mangaStatusAttr, mangaInLibraryAttr, mangaLastUpdatedAttr, mangaGenreAttr
        ]

        // CachedChapter Entity
        let chapterEntity = NSEntityDescription()
        chapterEntity.name = "CachedChapter"
        chapterEntity.managedObjectClassName = "CachedChapter"

        let chapterIdAttr = NSAttributeDescription()
        chapterIdAttr.name = "id"
        chapterIdAttr.attributeType = .integer32AttributeType

        let chapterMangaIdAttr = NSAttributeDescription()
        chapterMangaIdAttr.name = "mangaId"
        chapterMangaIdAttr.attributeType = .integer32AttributeType

        let chapterNameAttr = NSAttributeDescription()
        chapterNameAttr.name = "name"
        chapterNameAttr.attributeType = .stringAttributeType

        let chapterUrlAttr = NSAttributeDescription()
        chapterUrlAttr.name = "url"
        chapterUrlAttr.attributeType = .stringAttributeType

        let chapterNumberAttr = NSAttributeDescription()
        chapterNumberAttr.name = "chapterNumber"
        chapterNumberAttr.attributeType = .doubleAttributeType

        let chapterIsReadAttr = NSAttributeDescription()
        chapterIsReadAttr.name = "isRead"
        chapterIsReadAttr.attributeType = .booleanAttributeType

        let chapterIsDownloadedAttr = NSAttributeDescription()
        chapterIsDownloadedAttr.name = "isDownloaded"
        chapterIsDownloadedAttr.attributeType = .booleanAttributeType

        let chapterLastPageReadAttr = NSAttributeDescription()
        chapterLastPageReadAttr.name = "lastPageRead"
        chapterLastPageReadAttr.attributeType = .integer32AttributeType

        let chapterPageCountAttr = NSAttributeDescription()
        chapterPageCountAttr.name = "pageCount"
        chapterPageCountAttr.attributeType = .integer32AttributeType

        let chapterSourceOrderAttr = NSAttributeDescription()
        chapterSourceOrderAttr.name = "sourceOrder"
        chapterSourceOrderAttr.attributeType = .integer32AttributeType

        // Per-device progress tracking fields
        let chapterDeviceIdAttr = NSAttributeDescription()
        chapterDeviceIdAttr.name = "deviceId"
        chapterDeviceIdAttr.attributeType = .stringAttributeType
        chapterDeviceIdAttr.isOptional = true

        let chapterServerIsReadAttr = NSAttributeDescription()
        chapterServerIsReadAttr.name = "serverIsRead"
        chapterServerIsReadAttr.attributeType = .booleanAttributeType
        chapterServerIsReadAttr.defaultValue = false

        let chapterServerLastPageReadAttr = NSAttributeDescription()
        chapterServerLastPageReadAttr.name = "serverLastPageRead"
        chapterServerLastPageReadAttr.attributeType = .integer32AttributeType
        chapterServerLastPageReadAttr.defaultValue = 0

        let chapterLastReadAtAttr = NSAttributeDescription()
        chapterLastReadAtAttr.name = "lastReadAt"
        chapterLastReadAtAttr.attributeType = .dateAttributeType
        chapterLastReadAtAttr.isOptional = true

        chapterEntity.properties = [
            chapterIdAttr, chapterMangaIdAttr, chapterNameAttr, chapterUrlAttr,
            chapterNumberAttr, chapterIsReadAttr, chapterIsDownloadedAttr,
            chapterLastPageReadAttr, chapterPageCountAttr, chapterSourceOrderAttr,
            chapterDeviceIdAttr, chapterServerIsReadAttr, chapterServerLastPageReadAttr,
            chapterLastReadAtAttr
        ]

        // CachedImage Entity
        let imageEntity = NSEntityDescription()
        imageEntity.name = "CachedImage"
        imageEntity.managedObjectClassName = "CachedImage"

        let imageUrlAttr = NSAttributeDescription()
        imageUrlAttr.name = "url"
        imageUrlAttr.attributeType = .stringAttributeType

        let imageDataAttr = NSAttributeDescription()
        imageDataAttr.name = "data"
        imageDataAttr.attributeType = .binaryDataAttributeType
        imageDataAttr.allowsExternalBinaryDataStorage = true

        let imageCachedAtAttr = NSAttributeDescription()
        imageCachedAtAttr.name = "cachedAt"
        imageCachedAtAttr.attributeType = .dateAttributeType

        imageEntity.properties = [imageUrlAttr, imageDataAttr, imageCachedAtAttr]

        model.entities = [mangaEntity, chapterEntity, imageEntity]

        return model
    }

    // MARK: - Per-Device Progress Tracking

    func updateChapterProgress(chapterId: Int, deviceId: String, lastPageRead: Int, isRead: Bool) async throws {
        try await performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<CachedChapter> = NSFetchRequest(entityName: "CachedChapter")
            fetchRequest.predicate = NSPredicate(format: "id == %d AND deviceId == %@", Int32(chapterId), deviceId)

            let results = try context.fetch(fetchRequest)
            let chapter: CachedChapter

            if let existingChapter = results.first {
                chapter = existingChapter
            } else {
                chapter = NSEntityDescription.insertNewObject(forEntityName: "CachedChapter", into: context) as! CachedChapter
                chapter.id = Int32(chapterId)
                chapter.deviceId = deviceId
            }

            chapter.lastPageRead = Int32(lastPageRead)
            chapter.isRead = isRead
            chapter.lastReadAt = Date()

            try context.save()
        }
    }

    func getChapterProgress(chapterId: Int, deviceId: String) async throws -> (lastPageRead: Int, isRead: Bool)? {
        try await performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<CachedChapter> = NSFetchRequest(entityName: "CachedChapter")
            fetchRequest.predicate = NSPredicate(format: "id == %d AND deviceId == %@", Int32(chapterId), deviceId)

            guard let chapter = try context.fetch(fetchRequest).first else {
                return nil
            }

            return (Int(chapter.lastPageRead), chapter.isRead)
        }
    }

    /// Get device-specific read status for multiple chapters
    /// Returns a dictionary mapping chapter ID to read status
    func getChaptersReadStatus(chapterIds: [Int], deviceId: String) async throws -> [Int: Bool] {
        try await performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<CachedChapter> = NSFetchRequest(entityName: "CachedChapter")
            fetchRequest.predicate = NSPredicate(format: "id IN %@ AND deviceId == %@", chapterIds.map { Int32($0) }, deviceId)

            let chapters = try context.fetch(fetchRequest)
            var readStatus: [Int: Bool] = [:]

            for chapter in chapters {
                readStatus[Int(chapter.id)] = chapter.isRead
            }

            return readStatus
        }
    }

    /// Calculate device-specific unread count for a manga
    /// Takes chapters from server and checks device-specific progress
    func getDeviceUnreadCount(chapters: [Chapter], deviceId: String) async throws -> Int {
        let chapterIds = chapters.map { $0.id }
        let deviceReadStatus = try await getChaptersReadStatus(chapterIds: chapterIds, deviceId: deviceId)

        var unreadCount = 0
        for chapter in chapters {
            // If we have device-specific progress, use that; otherwise use server status
            let isRead = deviceReadStatus[chapter.id] ?? chapter.isRead
            if !isRead {
                unreadCount += 1
            }
        }

        return unreadCount
    }

    /// Update device-specific read status for multiple chapters
    func updateChaptersReadStatus(chapterIds: [Int], deviceId: String, isRead: Bool) async throws {
        try await performBackgroundTask { context in
            for chapterId in chapterIds {
                let fetchRequest: NSFetchRequest<CachedChapter> = NSFetchRequest(entityName: "CachedChapter")
                fetchRequest.predicate = NSPredicate(format: "id == %d AND deviceId == %@", Int32(chapterId), deviceId)

                let results = try context.fetch(fetchRequest)
                let chapter: CachedChapter

                if let existingChapter = results.first {
                    chapter = existingChapter
                } else {
                    chapter = NSEntityDescription.insertNewObject(forEntityName: "CachedChapter", into: context) as! CachedChapter
                    chapter.id = Int32(chapterId)
                    chapter.deviceId = deviceId
                }

                chapter.isRead = isRead
                chapter.lastReadAt = Date()
            }

            try context.save()
        }
    }
}

// MARK: - Managed Object Subclasses

@objc(CachedManga)
public class CachedManga: NSManagedObject {
    @NSManaged public var id: Int32
    @NSManaged public var title: String
    @NSManaged public var sourceId: String
    @NSManaged public var url: String
    @NSManaged public var thumbnailUrl: String?
    @NSManaged public var author: String?
    @NSManaged public var artist: String?
    @NSManaged public var mangaDescription: String?
    @NSManaged public var status: String
    @NSManaged public var inLibrary: Bool
    @NSManaged public var lastUpdated: Date?
    @NSManaged public var genreData: Data?

    var genre: [String] {
        get {
            guard let data = genreData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            genreData = try? JSONEncoder().encode(newValue)
        }
    }

    func toDomain() -> Manga {
        Manga(
            id: Int(id),
            sourceId: sourceId,
            url: url,
            title: title,
            thumbnailUrl: thumbnailUrl,
            artist: artist,
            author: author,
            description: mangaDescription,
            genre: genre,
            status: MangaStatus(rawValue: status) ?? .unknown,
            inLibrary: inLibrary
        )
    }

    func update(from manga: Manga) {
        self.id = Int32(manga.id)
        self.title = manga.title
        self.sourceId = manga.sourceId
        self.url = manga.url
        self.thumbnailUrl = manga.thumbnailUrl
        self.author = manga.author
        self.artist = manga.artist
        self.mangaDescription = manga.description
        self.status = manga.status.rawValue
        self.inLibrary = manga.inLibrary
        self.genre = manga.genre
        self.lastUpdated = Date()
    }
}

@objc(CachedChapter)
public class CachedChapter: NSManagedObject {
    @NSManaged public var id: Int32
    @NSManaged public var mangaId: Int32
    @NSManaged public var name: String
    @NSManaged public var url: String
    @NSManaged public var chapterNumber: Double
    @NSManaged public var isRead: Bool
    @NSManaged public var isDownloaded: Bool
    @NSManaged public var lastPageRead: Int32
    @NSManaged public var pageCount: Int32
    @NSManaged public var sourceOrder: Int32

    // Per-device progress tracking
    @NSManaged public var deviceId: String?
    @NSManaged public var serverIsRead: Bool
    @NSManaged public var serverLastPageRead: Int32
    @NSManaged public var lastReadAt: Date?

    func toDomain() -> Chapter {
        Chapter(
            id: Int(id),
            mangaId: Int(mangaId),
            url: url,
            name: name,
            chapterNumber: chapterNumber,
            sourceOrder: Int(sourceOrder),
            isRead: isRead,
            isDownloaded: isDownloaded,
            lastPageRead: Int(lastPageRead),
            pageCount: Int(pageCount)
        )
    }

    func update(from chapter: Chapter) {
        self.id = Int32(chapter.id)
        self.mangaId = Int32(chapter.mangaId)
        self.name = chapter.name
        self.url = chapter.url
        self.chapterNumber = chapter.chapterNumber
        self.serverIsRead = chapter.isRead
        self.serverLastPageRead = Int32(chapter.lastPageRead)
        self.isRead = chapter.isRead
        self.isDownloaded = chapter.isDownloaded
        self.lastPageRead = Int32(chapter.lastPageRead)
        self.pageCount = Int32(chapter.pageCount)
        self.sourceOrder = Int32(chapter.sourceOrder)
    }
}

@objc(CachedImage)
public class CachedImage: NSManagedObject {
    @NSManaged public var url: String
    @NSManaged public var data: Data?
    @NSManaged public var cachedAt: Date?
}
