import UIKit
import Kingfisher

protocol ManhwaReaderViewControllerDelegate: AnyObject {
    func manhwaReaderDidTapToToggleControls()
    func manhwaReaderDidUpdateProgress(chapter: Chapter, scrollPercentage: CGFloat, pageIndex: Int)
    func manhwaReaderWillDismiss()
    func manhwaReaderDidChangeChapter(from: Chapter, to: Chapter, direction: ScrollDirection)
    func manhwaReaderNeedsNextChapter(after: Chapter, completion: @escaping ([Page]?, Chapter?) -> Void)
    func manhwaReaderNeedsPreviousChapter(before: Chapter, completion: @escaping ([Page]?, Chapter?) -> Void)
    func manhwaReaderDidReachLastChapter()
}

final class ManhwaReaderViewController: UIViewController {

    weak var delegate: ManhwaReaderViewControllerDelegate?

    private let initialChapter: Chapter
    private let allChapters: [Chapter]
    private let serverUrl: String
    private let authHeader: String?
    private var initialScrollPercentage: Double?

    private var windowManager: ChapterWindowManager!
    private var collectionView: UICollectionView!
    private var progressBar: UIProgressView!

    private var screenWidth: CGFloat = 0
    private var hasSetInitialOffset = false
    private var scrollThrottleTimer: Timer?
    private let scrollThrottleInterval: TimeInterval = 0.1

    private var lastActiveSection: Int = 0
    private let prefetchThresholdScreens: CGFloat = 2.0

    private var isPrefetchingNext = false
    private var isPrefetchingPrevious = false
    private var hasReachedLastChapter = false

    init(initialChapter: Chapter,
         initialPages: [Page],
         allChapters: [Chapter],
         serverUrl: String,
         authHeader: String?,
         initialScrollPercentage: Double? = nil) {
        self.initialChapter = initialChapter
        self.allChapters = allChapters
        self.serverUrl = serverUrl
        self.authHeader = authHeader
        self.initialScrollPercentage = initialScrollPercentage
        super.init(nibName: nil, bundle: nil)

        // Initialize window manager with initial chapter
        self.windowManager = ChapterWindowManager(serverUrl: serverUrl)
        self.windowManager.delegate = self
        self.windowManager.setInitialChapter(initialChapter, pages: initialPages)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        screenWidth = view.bounds.width
        setupCollectionView()
        setupProgressBar()
        setupTapGesture()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if !hasSetInitialOffset, let percentage = initialScrollPercentage, percentage > 0 {
            collectionView.layoutIfNeeded()
            // Calculate actual offset from percentage after layout is complete
            let scrollableHeight = collectionView.contentSize.height - collectionView.bounds.height
            if scrollableHeight > 0 {
                let targetOffset = CGFloat(percentage) * scrollableHeight
                let clampedOffset = min(max(0, targetOffset), scrollableHeight)
                collectionView.contentOffset = CGPoint(x: 0, y: clampedOffset)
            }
            hasSetInitialOffset = true
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if screenWidth != view.bounds.width {
            screenWidth = view.bounds.width
            // Clear all cached heights on rotation
            for i in 0..<windowManager.chapters.count {
                windowManager.chapters[i].pageHeights.removeAll()
            }
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveCurrentProgress()
        delegate?.manhwaReaderWillDismiss()
        windowManager.invalidate()
    }

    // MARK: - Setup

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .black
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.register(ManhwaImageCell.self, forCellWithReuseIdentifier: ManhwaImageCell.reuseIdentifier)
        collectionView.register(
            ChapterHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: ChapterHeaderView.reuseIdentifier
        )
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never

        view.addSubview(collectionView)
    }

    private func setupProgressBar() {
        progressBar = UIProgressView(progressViewStyle: .bar)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progressTintColor = .white
        progressBar.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        progressBar.progress = 0

        view.addSubview(progressBar)

        NSLayoutConstraint.activate([
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 2)
        ])
    }

    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.numberOfTapsRequired = 1
        collectionView.addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap() {
        delegate?.manhwaReaderDidTapToToggleControls()
    }

    // MARK: - Cell Height Calculation

    private func calculateCellHeight(for indexPath: IndexPath) -> CGFloat {
        // First check cached height
        if let cachedHeight = windowManager.cachedPageHeight(forPage: indexPath.item, inSection: indexPath.section) {
            return cachedHeight
        }
        // Default height (will be updated when image loads)
        return screenWidth * 1.5
    }

    // MARK: - Progress Tracking

    private func saveCurrentProgress() {
        // Progress is now saved via delegate callback to ReaderViewModel
    }

    private func updateProgressThrottled() {
        scrollThrottleTimer?.invalidate()
        scrollThrottleTimer = Timer.scheduledTimer(withTimeInterval: scrollThrottleInterval, repeats: false) { [weak self] _ in
            self?.updateProgress()
        }
    }

    private func updateProgress() {
        guard !windowManager.chapters.isEmpty else { return }

        detectActiveChapter()
        checkPrefetchTrigger()
        updateProgressBar()
    }

    private func detectActiveChapter() {
        // Find center point of visible area
        let centerY = collectionView.contentOffset.y + collectionView.bounds.height / 2
        let centerPoint = CGPoint(x: collectionView.bounds.midX, y: centerY)

        // Get section at center
        if let indexPath = collectionView.indexPathForItem(at: centerPoint) {
            let newSection = indexPath.section
            if newSection != lastActiveSection && newSection < windowManager.chapters.count {
                let oldChapter = windowManager.chapters[lastActiveSection].chapter
                let newChapter = windowManager.chapters[newSection].chapter
                let direction: ScrollDirection = newSection > lastActiveSection ? .forward : .backward

                lastActiveSection = newSection
                windowManager.updateWindow(activeSection: newSection)
                delegate?.manhwaReaderDidChangeChapter(from: oldChapter, to: newChapter, direction: direction)
            }

            // Report progress for current chapter
            let currentChapter = windowManager.chapters[newSection].chapter

            // Calculate percentage within current chapter
            let chapterPercentage = calculateChapterScrollPercentage(section: newSection)
            delegate?.manhwaReaderDidUpdateProgress(chapter: currentChapter, scrollPercentage: chapterPercentage, pageIndex: indexPath.item)
        }
    }

    private func calculateChapterScrollPercentage(section: Int) -> CGFloat {
        guard section < windowManager.chapters.count else { return 0 }

        // Find the y-position range for this section
        var sectionStartY: CGFloat = 0
        for i in 0..<section {
            sectionStartY += heightForSection(i)
        }

        let sectionHeight = heightForSection(section)
        let currentOffset = collectionView.contentOffset.y
        let offsetInSection = currentOffset - sectionStartY + collectionView.bounds.height / 2

        guard sectionHeight > 0 else { return 0 }
        return min(1, max(0, offsetInSection / sectionHeight))
    }

    private func heightForSection(_ section: Int) -> CGFloat {
        guard section < windowManager.chapters.count else { return 0 }

        let chapter = windowManager.chapters[section]
        var totalHeight = ChapterHeaderView.height // Header height

        for i in 0..<chapter.pages.count {
            if let cachedHeight = chapter.pageHeights[i] {
                totalHeight += cachedHeight
            } else {
                totalHeight += screenWidth * 1.5 // Default height
            }
        }

        return totalHeight
    }

    private func updateProgressBar() {
        // Calculate overall progress across all loaded chapters
        let offsetY = collectionView.contentOffset.y
        let contentHeight = collectionView.contentSize.height
        let viewHeight = collectionView.bounds.height

        let scrollableHeight = contentHeight - viewHeight
        let percentage: CGFloat = scrollableHeight > 0 ? min(1, max(0, offsetY / scrollableHeight)) : 0

        progressBar.setProgress(Float(percentage), animated: false)
    }

    // MARK: - Prefetch Trigger

    private func checkPrefetchTrigger() {
        let viewHeight = collectionView.bounds.height
        let currentOffset = collectionView.contentOffset.y
        let contentHeight = collectionView.contentSize.height

        // Check bottom - need next chapter
        let distanceFromBottom = contentHeight - (currentOffset + viewHeight)
        if distanceFromBottom < viewHeight * prefetchThresholdScreens {
            prefetchNextChapter()
        }

        // Check top - need previous chapter
        if currentOffset < viewHeight * prefetchThresholdScreens {
            prefetchPreviousChapter()
        }
    }

    private func prefetchNextChapter() {
        guard !isPrefetchingNext && !hasReachedLastChapter else { return }
        guard let lastChapter = windowManager.chapters.last?.chapter else { return }

        // Find next chapter in allChapters (chapters are sorted newest first, so "next" is lower index)
        guard let currentIndex = allChapters.firstIndex(where: { $0.id == lastChapter.id }) else { return }
        let nextIndex = currentIndex - 1
        guard nextIndex >= 0 else {
            hasReachedLastChapter = true
            delegate?.manhwaReaderDidReachLastChapter()
            return
        }

        let nextChapter = allChapters[nextIndex]
        guard !windowManager.containsChapter(nextChapter.id) else { return }

        isPrefetchingNext = true
        delegate?.manhwaReaderNeedsNextChapter(after: lastChapter) { [weak self] pages, chapter in
            guard let self = self, let pages = pages, let chapter = chapter else {
                self?.isPrefetchingNext = false
                return
            }
            self.appendChapter(chapter, pages: pages)
            self.isPrefetchingNext = false
        }
    }

    private func prefetchPreviousChapter() {
        guard !isPrefetchingPrevious else { return }
        guard let firstChapter = windowManager.chapters.first?.chapter else { return }

        // Find previous chapter in allChapters (chapters are sorted newest first, so "previous" is higher index)
        guard let currentIndex = allChapters.firstIndex(where: { $0.id == firstChapter.id }) else { return }
        let previousIndex = currentIndex + 1
        guard previousIndex < allChapters.count else { return }

        let previousChapter = allChapters[previousIndex]
        guard !windowManager.containsChapter(previousChapter.id) else { return }

        isPrefetchingPrevious = true
        delegate?.manhwaReaderNeedsPreviousChapter(before: firstChapter) { [weak self] pages, chapter in
            guard let self = self, let pages = pages, let chapter = chapter else {
                self?.isPrefetchingPrevious = false
                return
            }
            self.prependChapter(chapter, pages: pages)
            self.isPrefetchingPrevious = false
        }
    }

    // MARK: - Chapter Insertion

    private func appendChapter(_ chapter: Chapter, pages: [Page]) {
        let newSectionIndex = windowManager.appendChapter(chapter, pages: pages)

        collectionView.performBatchUpdates {
            collectionView.insertSections(IndexSet(integer: newSectionIndex))
        }
    }

    private func prependChapter(_ chapter: Chapter, pages: [Page]) {
        let currentOffset = collectionView.contentOffset

        windowManager.prependChapter(chapter, pages: pages)
        lastActiveSection += 1  // Adjust since we inserted at beginning

        collectionView.performBatchUpdates {
            collectionView.insertSections(IndexSet(integer: 0))
        } completion: { [weak self] _ in
            guard let self = self else { return }
            // Adjust offset to maintain visual position
            let newSectionHeight = self.heightForSection(0)
            self.collectionView.contentOffset = CGPoint(x: 0, y: currentOffset.y + newSectionHeight)
        }
    }

    // MARK: - Public Interface

    func scrollToOffset(_ offset: CGFloat, animated: Bool = false) {
        let maxOffset = max(0, collectionView.contentSize.height - collectionView.bounds.height)
        let clampedOffset = min(offset, maxOffset)
        collectionView.setContentOffset(CGPoint(x: 0, y: clampedOffset), animated: animated)
    }

    func reloadPage(at indexPath: IndexPath) {
        guard indexPath.section < windowManager.chapters.count,
              indexPath.item < windowManager.chapters[indexPath.section].pages.count else { return }

        if let cell = collectionView.cellForItem(at: indexPath) as? ManhwaImageCell {
            let page = windowManager.chapters[indexPath.section].pages[indexPath.item]
            let url = page.effectiveUrl?.toManhwaImageURL(serverUrl: serverUrl)
            cell.configure(
                with: url,
                index: indexPath.item,
                section: indexPath.section,
                options: ManhwaImageOptions.defaultOptions(screenWidth: screenWidth, serverUrl: serverUrl, authHeader: authHeader)
            )
        }
    }

    /// Get the current active chapter
    var currentChapter: Chapter? {
        guard lastActiveSection < windowManager.chapters.count else { return nil }
        return windowManager.chapters[lastActiveSection].chapter
    }
}

// MARK: - UICollectionViewDataSource

extension ManhwaReaderViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return windowManager.chapters.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard section < windowManager.chapters.count else { return 0 }
        return windowManager.chapters[section].pages.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ManhwaImageCell.reuseIdentifier, for: indexPath) as! ManhwaImageCell
        cell.delegate = self

        guard indexPath.section < windowManager.chapters.count,
              indexPath.item < windowManager.chapters[indexPath.section].pages.count else {
            return cell
        }

        let chapterSection = windowManager.chapters[indexPath.section]

        // Check if chapter is unloaded (memory windowing)
        if chapterSection.loadState == .unloaded {
            cell.configureAsPlaceholder(index: indexPath.item, section: indexPath.section)
        } else {
            let page = chapterSection.pages[indexPath.item]
            let url = page.effectiveUrl?.toManhwaImageURL(serverUrl: serverUrl)
            cell.configure(
                with: url,
                index: indexPath.item,
                section: indexPath.section,
                options: ManhwaImageOptions.defaultOptions(screenWidth: screenWidth, serverUrl: serverUrl, authHeader: authHeader)
            )
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }

        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: ChapterHeaderView.reuseIdentifier,
            for: indexPath
        ) as! ChapterHeaderView

        if indexPath.section < windowManager.chapters.count {
            let chapter = windowManager.chapters[indexPath.section].chapter
            header.configure(with: chapter.displayName)
        }

        return header
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension ManhwaReaderViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let height = calculateCellHeight(for: indexPath)
        return CGSize(width: screenWidth, height: height)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        // Only show header for sections after the first one
        if section == 0 {
            return .zero
        }
        return CGSize(width: screenWidth, height: ChapterHeaderView.height)
    }
}

// MARK: - UICollectionViewDataSourcePrefetching

extension ManhwaReaderViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let urls = indexPaths.compactMap { indexPath -> URL? in
            guard indexPath.section < windowManager.chapters.count,
                  indexPath.item < windowManager.chapters[indexPath.section].pages.count else {
                return nil
            }
            let chapter = windowManager.chapters[indexPath.section]
            guard chapter.loadState == .loaded else { return nil }
            return chapter.pages[indexPath.item].effectiveUrl?.toManhwaImageURL(serverUrl: serverUrl)
        }

        guard !urls.isEmpty else { return }

        let prefetcher = ImagePrefetcher(
            urls: urls,
            options: ManhwaImageOptions.prefetchOptions(screenWidth: screenWidth, serverUrl: serverUrl, authHeader: authHeader)
        )
        prefetcher.start()
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let urls = indexPaths.compactMap { indexPath -> URL? in
            guard indexPath.section < windowManager.chapters.count,
                  indexPath.item < windowManager.chapters[indexPath.section].pages.count else {
                return nil
            }
            return windowManager.chapters[indexPath.section].pages[indexPath.item].effectiveUrl?.toManhwaImageURL(serverUrl: serverUrl)
        }
        guard !urls.isEmpty else { return }
        ImagePrefetcher(urls: urls).stop()
    }
}

// MARK: - UIScrollViewDelegate

extension ManhwaReaderViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateProgressThrottled()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        windowManager.updateWindowImmediate(activeSection: lastActiveSection)
        saveCurrentProgress()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            windowManager.updateWindowImmediate(activeSection: lastActiveSection)
            saveCurrentProgress()
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        windowManager.updateWindowImmediate(activeSection: lastActiveSection)
    }
}

// MARK: - ManhwaImageCellDelegate

extension ManhwaReaderViewController: ManhwaImageCellDelegate {
    func manhwaImageCell(_ cell: ManhwaImageCell, didLoadImageWithSize size: CGSize, atIndex index: Int, inSection section: Int) {
        guard section < windowManager.chapters.count else { return }

        // Check if we already have this height cached
        if windowManager.cachedPageHeight(forPage: index, inSection: section) != nil {
            return
        }

        let height = screenWidth * (size.height / size.width)
        windowManager.cachePageHeight(height, forPage: index, inSection: section)

        let context = UICollectionViewFlowLayoutInvalidationContext()
        context.invalidateItems(at: [IndexPath(item: index, section: section)])
        collectionView.collectionViewLayout.invalidateLayout(with: context)
    }

    func manhwaImageCellDidRequestRetry(_ cell: ManhwaImageCell, atIndex index: Int, inSection section: Int) {
        reloadPage(at: IndexPath(item: index, section: section))
    }
}

// MARK: - ChapterWindowManagerDelegate

extension ManhwaReaderViewController: ChapterWindowManagerDelegate {
    func chapterWindowManager(_ manager: ChapterWindowManager, didLoadChapterAt index: Int) {
        // Reload section to show actual images instead of placeholders
        collectionView.reloadSections(IndexSet(integer: index))
    }

    func chapterWindowManager(_ manager: ChapterWindowManager, didUnloadChapterAt index: Int) {
        // Reload section to show placeholders (heights preserved)
        collectionView.reloadSections(IndexSet(integer: index))
    }
}
