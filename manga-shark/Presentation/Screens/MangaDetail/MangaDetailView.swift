import SwiftUI
import Combine

struct MangaDetailView: View {
    let mangaId: Int
    @StateObject private var viewModel: MangaDetailViewModel
    @State private var showingCategorySheet = false

    init(mangaId: Int) {
        self.mangaId = mangaId
        _viewModel = StateObject(wrappedValue: MangaDetailViewModel(mangaId: mangaId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.manga == nil {
                ProgressView("Loading...")
            } else if let manga = viewModel.manga {
                mangaContent(manga)
            } else {
                EmptyStateView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(viewModel.errorMessage ?? "Failed to load manga")
                }
            }
        }
        .navigationTitle(viewModel.manga?.title ?? "Manga")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let manga = viewModel.manga {
                    Menu {
                        Button(action: {
                            Task { await viewModel.toggleLibrary() }
                        }) {
                            Label(
                                manga.inLibrary ? "Remove from Library" : "Add to Library",
                                systemImage: manga.inLibrary ? "bookmark.slash" : "bookmark"
                            )
                        }

                        if manga.inLibrary {
                            Button(action: { showingCategorySheet = true }) {
                                Label("Edit Categories", systemImage: "folder")
                            }
                        }

                        Divider()

                        Button(action: {
                            Task { await viewModel.refreshChapters() }
                        }) {
                            Label("Refresh Chapters", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            await viewModel.loadManga()
        }
        .refreshable {
            await viewModel.loadManga(forceRefresh: true)
        }
        .navigationDestination(for: Chapter.self) { chapter in
            ReaderView(chapter: chapter, chapters: viewModel.chapters)
        }
    }

    @ViewBuilder
    private func mangaContent(_ manga: Manga) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection(manga)
                actionButtons(manga)
                descriptionSection(manga)
                chaptersSection
            }
            .padding()
        }
    }

    @ViewBuilder
    private func headerSection(_ manga: Manga) -> some View {
        HStack(alignment: .top, spacing: 16) {
            AsyncCachedImage(url: manga.thumbnailUrl)
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 120, height: 180)
                .clipped()
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 8) {
                Text(manga.title)
                    .font(.headline)
                    .lineLimit(3)

                if let author = manga.author {
                    Label(author, systemImage: "person")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let artist = manga.artist, artist != manga.author {
                    Label(artist, systemImage: "paintbrush")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    StatusBadge(status: manga.status)
                }

                if !manga.genre.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(manga.genre.prefix(5), id: \.self) { genre in
                            Text(genre)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func actionButtons(_ manga: Manga) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                Task { await viewModel.toggleLibrary() }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: manga.inLibrary ? "bookmark.fill" : "bookmark")
                        .font(.title2)
                    Text(manga.inLibrary ? "In Library" : "Add to Library")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(manga.inLibrary ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .foregroundStyle(manga.inLibrary ? .blue : .primary)

            if let firstUnread = viewModel.firstUnreadChapter {
                NavigationLink(value: firstUnread) {
                    VStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.title2)
                        Text(viewModel.continueButtonText)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func descriptionSection(_ manga: Manga) -> some View {
        if let description = manga.description, !description.isEmpty {
            DisclosureGroup("Description") {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var chaptersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(viewModel.chapters.count) Chapters")
                    .font(.headline)

                Spacer()

                Menu {
                    Button(action: {
                        Task { await viewModel.markAllRead() }
                    }) {
                        Label("Mark All Read", systemImage: "checkmark.circle")
                    }

                    Button(action: {
                        Task { await viewModel.markAllUnread() }
                    }) {
                        Label("Mark All Unread", systemImage: "circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            if viewModel.chapters.isEmpty {
                Text("No chapters available")
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.chapters) { chapter in
                        NavigationLink(value: chapter) {
                            ChapterRowView(
                                chapter: chapter,
                                isRead: viewModel.deviceReadStatus[chapter.id] ?? chapter.isRead
                            )
                        }
                        .buttonStyle(.plain)

                        if chapter.id != viewModel.chapters.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }
        }
    }
}

struct StatusBadge: View {
    let status: MangaStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .cornerRadius(4)
    }

    private var backgroundColor: Color {
        switch status {
        case .ongoing: return .green.opacity(0.2)
        case .completed: return .blue.opacity(0.2)
        case .onHiatus: return .orange.opacity(0.2)
        case .cancelled: return .red.opacity(0.2)
        default: return .gray.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .ongoing: return .green
        case .completed: return .blue
        case .onHiatus: return .orange
        case .cancelled: return .red
        default: return .gray
        }
    }
}

struct ChapterRowView: View {
    let chapter: Chapter
    let isRead: Bool

    init(chapter: Chapter, isRead: Bool? = nil) {
        self.chapter = chapter
        self.isRead = isRead ?? chapter.isRead
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(chapter.displayName)
                    .font(.body)
                    .foregroundStyle(isRead ? .secondary : .primary)

                HStack(spacing: 8) {
                    if let scanlator = chapter.scanlator, !scanlator.isEmpty {
                        Text(scanlator)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let uploadDate = chapter.uploadDate {
                        Text(uploadDate, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if chapter.isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.green)
                }

                if chapter.isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(.yellow)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

@MainActor
final class MangaDetailViewModel: ObservableObject {
    let mangaId: Int

    @Published var manga: Manga?
    @Published var chapters: [Chapter] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var deviceReadStatus: [Int: Bool] = [:] // chapter ID -> device-specific read status

    var firstUnreadChapter: Chapter? {
        // Use device-specific read status if available, otherwise use server status
        chapters.last { chapter in
            let isRead = deviceReadStatus[chapter.id] ?? chapter.isRead
            return !isRead
        } ?? chapters.first
    }

    var hasStartedReading: Bool {
        // Check if any chapter has been read on this device
        for chapter in chapters {
            let isRead = deviceReadStatus[chapter.id] ?? chapter.isRead
            if isRead {
                return true
            }
        }
        return false
    }

    var continueButtonText: String {
        guard let firstUnread = firstUnreadChapter else {
            return "Start Reading"
        }

        if hasStartedReading {
            return "Continue Ch. \(Int(firstUnread.chapterNumber))"
        } else {
            return "Start Reading"
        }
    }

    init(mangaId: Int) {
        self.mangaId = mangaId
    }

    func loadManga(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil

        do {
            manga = try await MangaRepository.shared.getManga(id: mangaId, forceRefresh: forceRefresh)
            chapters = try await MangaRepository.shared.getChapters(mangaId: mangaId)
            chapters.sort { $0.sourceOrder > $1.sourceOrder }

            // Load device-specific read status
            await loadDeviceReadStatus()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadDeviceReadStatus() async {
        let deviceId = DeviceIdentifierManager.shared.deviceId
        let chapterIds = chapters.map { $0.id }

        do {
            deviceReadStatus = try await CoreDataStack.shared.getChaptersReadStatus(chapterIds: chapterIds, deviceId: deviceId)
        } catch {
            // Failed to load device status, will fall back to server status
            print("Failed to load device read status: \(error)")
        }
    }

    func refreshChapters() async {
        isLoading = true
        do {
            chapters = try await MangaRepository.shared.fetchChapters(mangaId: mangaId)
            chapters.sort { $0.sourceOrder > $1.sourceOrder }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func toggleLibrary() async {
        guard let manga = manga else { return }

        do {
            self.manga = try await MangaRepository.shared.updateLibraryStatus(
                mangaId: manga.id,
                inLibrary: !manga.inLibrary
            )
            await LibraryRepository.shared.invalidateLibrary()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAllRead() async {
        let chapterIds = chapters.filter { !$0.isRead }.map { $0.id }
        guard !chapterIds.isEmpty else { return }

        // Repository handles both local save and server sync
        await ChapterRepository.shared.markChaptersRead(chapterIds: chapterIds, isRead: true)
        await loadManga(forceRefresh: true)
    }

    func markAllUnread() async {
        let chapterIds = chapters.filter { $0.isRead }.map { $0.id }
        guard !chapterIds.isEmpty else { return }

        // Repository handles both local save and server sync
        await ChapterRepository.shared.markChaptersRead(chapterIds: chapterIds, isRead: false)
        await loadManga(forceRefresh: true)
    }
}

#Preview {
    NavigationStack {
        MangaDetailView(mangaId: 1)
    }
}
