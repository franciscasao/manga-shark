import SwiftUI
import Combine

struct ReaderView: View {
    let chapter: Chapter
    let chapters: [Chapter]

    @StateObject private var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showControls = true

    init(chapter: Chapter, chapters: [Chapter]) {
        self.chapter = chapter
        self.chapters = chapters
        _viewModel = StateObject(wrappedValue: ReaderViewModel(chapter: chapter, chapters: chapters))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.isLoading && viewModel.pages.isEmpty {
                    ProgressView("Loading pages...")
                        .tint(.white)
                } else if viewModel.pages.isEmpty {
                    EmptyStateView {
                        Label("No Pages", systemImage: "photo")
                    } description: {
                        Text(viewModel.errorMessage ?? "Failed to load chapter pages")
                    }
                    .foregroundStyle(.white)
                } else {
                    readerContent(geometry: geometry)
                }

                if showControls && !viewModel.pages.isEmpty {
                    controlsOverlay
                }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: !showControls)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await viewModel.loadPages()
        }
        .onDisappear {
            Task {
                await viewModel.saveProgress()
            }
        }
        .sheet(isPresented: $viewModel.showSettings) {
            readerSettingsSheet
        }
    }

    @ViewBuilder
    private func readerContent(geometry: GeometryProxy) -> some View {
        switch viewModel.readerMode {
        case .paged:
            PagedReaderView(
                pages: viewModel.pages,
                currentPage: $viewModel.currentPageIndex,
                direction: viewModel.readingDirection,
                onTap: { toggleControls() }
            )
        case .webtoon:
            ManhwaReaderRepresentable(
                pages: viewModel.pages,
                chapterId: viewModel.currentChapter.id,
                serverUrl: AuthManager.shared.serverConfig.serverUrl,
                authHeader: AuthManager.shared.authorizationHeader,
                initialScrollPercentage: viewModel.manhwaScrollPercentage
            )
            .onTapToToggleControls { toggleControls() }
            .onProgressUpdate { percentage, offsetY, visibleIndex in
                viewModel.updateManhwaProgress(scrollPercentage: percentage, offsetY: offsetY, visiblePageIndex: visibleIndex)
            }
            .onReachEnd {
                // Could trigger next chapter here if desired
            }
            .ignoresSafeArea()
        }
    }

    private var controlsOverlay: some View {
        VStack {
            topBar
            Spacer()
            bottomBar
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.currentChapter.displayName)
                    .font(.headline)
                Text("\(viewModel.currentPageIndex + 1) / \(viewModel.pages.count)")
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(8)

            Spacer()

            Button(action: { viewModel.showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding()
        .foregroundStyle(.white)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Slider(
                value: Binding(
                    get: { Double(viewModel.currentPageIndex) },
                    set: { viewModel.currentPageIndex = Int($0) }
                ),
                in: 0...Double(viewModel.pages.count > 0 ? viewModel.pages.count - 1 : 0),
                step: 1
            )
            .tint(.white)

            HStack {
                Button(action: {
                    Task { await viewModel.previousChapter() }
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                }
                .disabled(!viewModel.hasPreviousChapter)

                Spacer()

                Button(action: {
                    Task { await viewModel.nextChapter() }
                }) {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                }
                .disabled(!viewModel.hasNextChapter)
            }
            .font(.subheadline)
        }
        .padding()
        .background(.ultraThinMaterial)
        .foregroundStyle(.white)
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showControls.toggle()
        }
    }

    private var readerSettingsSheet: some View {
        NavigationStack {
            Form {
                Section("Reader Mode") {
                    Picker("Mode", selection: Binding(
                        get: { viewModel.readerMode },
                        set: { viewModel.setReaderMode($0) }
                    )) {
                        ForEach(ReaderMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Reading Direction") {
                    Picker("Direction", selection: Binding(
                        get: { viewModel.readingDirection },
                        set: { viewModel.setReadingDirection($0) }
                    )) {
                        ForEach(ReadingDirection.allCases, id: \.self) { direction in
                            Text(direction.displayName).tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Reader Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        viewModel.showSettings = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct PagedReaderView: View {
    let pages: [Page]
    @Binding var currentPage: Int
    let direction: ReadingDirection
    let onTap: () -> Void

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                PageImageView(page: page)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .environment(\.layoutDirection, direction == .rightToLeft ? .rightToLeft : .leftToRight)
        .onTapGesture {
            onTap()
        }
    }
}

struct WebtoonReaderView: View {
    let pages: [Page]
    @Binding var currentPage: Int
    let onTap: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        PageImageView(page: page)
                            .id(index)
                    }
                }
            }
            .onAppear {
                // Set initial position without animation
                proxy.scrollTo(currentPage, anchor: .top)
            }
            .onChange(of: currentPage) { newValue in
                // Animate subsequent page changes
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .top)
                }
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}

struct PageImageView: View {
    let page: Page
    @State private var imageData: Data?
    @State private var isLoading = false
    @State private var error: Error?

    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
                    .tint(.white)
            } else if error != nil {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text("Failed to load")
                        .font(.caption)
                    Button("Retry") {
                        Task { await loadImage() }
                    }
                    .buttonStyle(.bordered)
                }
                .foregroundStyle(.white)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url = page.effectiveUrl else { return }
        guard imageData == nil else { return }

        isLoading = true
        error = nil

        do {
            imageData = try await NetworkClient.shared.fetchImage(from: url)
        } catch {
            self.error = error
        }

        isLoading = false
    }
}

enum ReaderMode: String, CaseIterable {
    case paged
    case webtoon

    var displayName: String {
        switch self {
        case .paged: return "Paged"
        case .webtoon: return "Webtoon"
        }
    }
}

enum ReadingDirection: String, CaseIterable {
    case leftToRight
    case rightToLeft

    var displayName: String {
        switch self {
        case .leftToRight: return "Left to Right"
        case .rightToLeft: return "Right to Left"
        }
    }
}

@MainActor
final class ReaderViewModel: ObservableObject {
    let initialChapter: Chapter
    let chapters: [Chapter]

    @Published var currentChapter: Chapter
    @Published var pages: [Page] = []
    @Published var currentPageIndex: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var readerMode: ReaderMode = .paged
    @Published var readingDirection: ReadingDirection = .rightToLeft
    @Published var showSettings = false
    @Published var manhwaScrollPercentage: Double = 0

    var hasPreviousChapter: Bool {
        guard let currentIndex = chapters.firstIndex(where: { $0.id == currentChapter.id }) else {
            return false
        }
        return currentIndex < chapters.count - 1
    }

    var hasNextChapter: Bool {
        guard let currentIndex = chapters.firstIndex(where: { $0.id == currentChapter.id }) else {
            return false
        }
        return currentIndex > 0
    }

    init(chapter: Chapter, chapters: [Chapter]) {
        self.initialChapter = chapter
        self.currentChapter = chapter
        self.chapters = chapters

        if let savedMode = UserDefaults.standard.string(forKey: UserDefaultsKeys.readerMode),
           let mode = ReaderMode(rawValue: savedMode) {
            self.readerMode = mode
        }

        if let savedDirection = UserDefaults.standard.string(forKey: UserDefaultsKeys.readerDirection),
           let direction = ReadingDirection(rawValue: savedDirection) {
            self.readingDirection = direction
        }
    }

    func loadPages() async {
        isLoading = true
        errorMessage = nil

        // Begin reading session
        ReadingProgressManager.shared.beginReading(chapterId: String(currentChapter.id))

        do {
            pages = try await ChapterRepository.shared.getChapterPages(chapterId: currentChapter.id)

            // Get progress from SwiftData (iOS 17+) or CoreData (iOS 16)
            if let progress: ProgressData = await ReadingProgressManager.shared.getProgress(for: String(currentChapter.id)) {
                // Use saved progress
                currentPageIndex = min(progress.lastPageIndex, max(0, pages.count - 1))
                manhwaScrollPercentage = progress.lastReadPercentage
            } else {
                // Fallback to server progress (for chapters not yet read)
                currentPageIndex = min(currentChapter.lastPageRead, max(0, pages.count - 1))

                // Calculate percentage from page index for webtoon mode
                if pages.count > 1 {
                    manhwaScrollPercentage = Double(currentPageIndex) / Double(pages.count - 1)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func updateManhwaProgress(scrollPercentage: CGFloat, offsetY: CGFloat, visiblePageIndex: Int) {
        manhwaScrollPercentage = Double(scrollPercentage)
        currentPageIndex = visiblePageIndex

        // Calculate which page we're on based on scroll percentage for progress tracking
        if !pages.isEmpty {
            let estimatedPage = Int(scrollPercentage * CGFloat(pages.count - 1))
            currentPageIndex = min(estimatedPage, pages.count - 1)
        }

        // Update progress in SwiftData (throttled)
        let isRead = scrollPercentage >= 0.95
        ReadingProgressManager.shared.updateProgress(
            chapterId: String(currentChapter.id),
            seriesId: String(currentChapter.mangaId),
            percentage: Double(scrollPercentage),
            pageIndex: currentPageIndex,
            isRead: isRead
        )
    }

    func saveProgress() async {
        guard !pages.isEmpty else { return }

        let isRead = currentPageIndex >= pages.count - 1

        // Calculate percentage based on mode
        let percentage: Double
        if readerMode == .webtoon {
            percentage = manhwaScrollPercentage
        } else {
            percentage = ReadingProgressManager.calculatePercentage(pageIndex: currentPageIndex, totalPages: pages.count)
        }

        // Save to SwiftData (syncs via CloudKit) and server
        ReadingProgressManager.shared.updateProgress(
            chapterId: String(currentChapter.id),
            seriesId: String(currentChapter.mangaId),
            percentage: percentage,
            pageIndex: currentPageIndex,
            isRead: isRead
        )

        // End reading session
        ReadingProgressManager.shared.endReading()

        // Also sync to server for non-iOS clients
        await ChapterRepository.shared.updateProgress(
            chapterId: currentChapter.id,
            lastPageRead: currentPageIndex,
            isRead: isRead
        )
    }

    func previousChapter() async {
        guard hasPreviousChapter,
              let currentIndex = chapters.firstIndex(where: { $0.id == currentChapter.id }) else {
            return
        }

        await saveProgress()
        pages = []  // Trigger loading view first
        currentChapter = chapters[currentIndex + 1]
        await loadPages()  // This will set currentPageIndex to saved progress
    }

    func nextChapter() async {
        guard hasNextChapter,
              let currentIndex = chapters.firstIndex(where: { $0.id == currentChapter.id }) else {
            return
        }

        await saveProgress()
        pages = []  // Trigger loading view first
        currentChapter = chapters[currentIndex - 1]
        await loadPages()  // This will set currentPageIndex to saved progress
    }

    func setReaderMode(_ mode: ReaderMode) {
        readerMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: UserDefaultsKeys.readerMode)
    }

    func setReadingDirection(_ direction: ReadingDirection) {
        readingDirection = direction
        UserDefaults.standard.set(direction.rawValue, forKey: UserDefaultsKeys.readerDirection)
    }
}

#Preview {
    ReaderView(
        chapter: Chapter.preview(),
        chapters: [Chapter.preview()]
    )
}
