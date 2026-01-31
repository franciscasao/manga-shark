import UIKit
import Kingfisher

protocol ManhwaReaderViewControllerDelegate: AnyObject {
    func manhwaReaderDidTapToToggleControls()
    func manhwaReaderDidUpdateProgress(scrollPercentage: CGFloat, offsetY: CGFloat, visiblePageIndex: Int)
    func manhwaReaderDidReachEnd()
    func manhwaReaderWillDismiss()
}

final class ManhwaReaderViewController: UIViewController {

    weak var delegate: ManhwaReaderViewControllerDelegate?

    private let pages: [Page]
    private let chapterId: Int
    private let serverUrl: String
    private let authHeader: String?
    private var initialScrollPercentage: Double?

    private var collectionView: UICollectionView!
    private var progressBar: UIProgressView!

    private var imageSizes: [Int: CGSize] = [:]
    private var screenWidth: CGFloat = 0
    private var hasSetInitialOffset = false
    private var scrollThrottleTimer: Timer?
    private let scrollThrottleInterval: TimeInterval = 0.1

    init(pages: [Page], chapterId: Int, serverUrl: String, authHeader: String?, initialScrollPercentage: Double? = nil) {
        self.pages = pages
        self.chapterId = chapterId
        self.serverUrl = serverUrl
        self.authHeader = authHeader
        self.initialScrollPercentage = initialScrollPercentage
        super.init(nibName: nil, bundle: nil)
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
            imageSizes.removeAll()
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveCurrentProgress()
        delegate?.manhwaReaderWillDismiss()
    }

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

    private func calculateCellHeight(for index: Int) -> CGFloat {
        if let size = imageSizes[index], size.width > 0 {
            return screenWidth * (size.height / size.width)
        }
        return screenWidth * 1.5
    }

    private func saveCurrentProgress() {
        // Progress is now saved via delegate callback to ReaderViewModel
        // which uses ReadingProgressManager (SwiftData + CloudKit)
    }

    private func updateProgressThrottled() {
        scrollThrottleTimer?.invalidate()
        scrollThrottleTimer = Timer.scheduledTimer(withTimeInterval: scrollThrottleInterval, repeats: false) { [weak self] _ in
            self?.updateProgress()
        }
    }

    private func updateProgress() {
        let offsetY = collectionView.contentOffset.y
        let contentHeight = collectionView.contentSize.height
        let viewHeight = collectionView.bounds.height

        let scrollableHeight = contentHeight - viewHeight
        let percentage: CGFloat = scrollableHeight > 0 ? min(1, max(0, offsetY / scrollableHeight)) : 0

        progressBar.setProgress(Float(percentage), animated: false)

        let visibleRect = CGRect(origin: collectionView.contentOffset, size: collectionView.bounds.size)
        let visibleCells = collectionView.visibleCells.compactMap { $0 as? ManhwaImageCell }
        let visibleIndex = visibleCells.first?.index ?? 0

        delegate?.manhwaReaderDidUpdateProgress(scrollPercentage: percentage, offsetY: offsetY, visiblePageIndex: visibleIndex)

        let nearEnd = offsetY + viewHeight >= contentHeight - 100
        if nearEnd && percentage > 0.95 {
            delegate?.manhwaReaderDidReachEnd()
        }
    }

    func scrollToOffset(_ offset: CGFloat, animated: Bool = false) {
        let maxOffset = max(0, collectionView.contentSize.height - collectionView.bounds.height)
        let clampedOffset = min(offset, maxOffset)
        collectionView.setContentOffset(CGPoint(x: 0, y: clampedOffset), animated: animated)
    }

    func reloadPage(at index: Int) {
        guard index >= 0 && index < pages.count else { return }

        if let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? ManhwaImageCell {
            let page = pages[index]
            let url = page.effectiveUrl?.toManhwaImageURL(serverUrl: serverUrl)
            cell.configure(with: url, index: index, options: ManhwaImageOptions.defaultOptions(screenWidth: screenWidth, serverUrl: serverUrl, authHeader: authHeader))
        }
    }
}

extension ManhwaReaderViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return pages.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ManhwaImageCell.reuseIdentifier, for: indexPath) as! ManhwaImageCell
        cell.delegate = self

        let page = pages[indexPath.item]
        let url = page.effectiveUrl?.toManhwaImageURL(serverUrl: serverUrl)
        cell.configure(with: url, index: indexPath.item, options: ManhwaImageOptions.defaultOptions(screenWidth: screenWidth, serverUrl: serverUrl, authHeader: authHeader))

        return cell
    }
}

extension ManhwaReaderViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let height = calculateCellHeight(for: indexPath.item)
        return CGSize(width: screenWidth, height: height)
    }
}

extension ManhwaReaderViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let urls = indexPaths.compactMap { indexPath -> URL? in
            guard indexPath.item < pages.count else { return nil }
            return pages[indexPath.item].effectiveUrl?.toManhwaImageURL(serverUrl: serverUrl)
        }

        let prefetcher = ImagePrefetcher(
            urls: urls,
            options: ManhwaImageOptions.prefetchOptions(screenWidth: screenWidth, serverUrl: serverUrl, authHeader: authHeader)
        )
        prefetcher.start()
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let urls = indexPaths.compactMap { indexPath -> URL? in
            guard indexPath.item < pages.count else { return nil }
            return pages[indexPath.item].effectiveUrl?.toManhwaImageURL(serverUrl: serverUrl)
        }
        ImagePrefetcher(urls: urls).stop()
    }
}

extension ManhwaReaderViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateProgressThrottled()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        saveCurrentProgress()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            saveCurrentProgress()
        }
    }
}

extension ManhwaReaderViewController: ManhwaImageCellDelegate {
    func manhwaImageCell(_ cell: ManhwaImageCell, didLoadImageWithSize size: CGSize, atIndex index: Int) {
        guard imageSizes[index] == nil else { return }

        imageSizes[index] = size

        let context = UICollectionViewFlowLayoutInvalidationContext()
        context.invalidateItems(at: [IndexPath(item: index, section: 0)])
        collectionView.collectionViewLayout.invalidateLayout(with: context)
    }

    func manhwaImageCellDidRequestRetry(_ cell: ManhwaImageCell, atIndex index: Int) {
        reloadPage(at: index)
    }
}
