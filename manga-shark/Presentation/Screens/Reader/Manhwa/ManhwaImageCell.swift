import UIKit
import Kingfisher

protocol ManhwaImageCellDelegate: AnyObject {
    func manhwaImageCell(_ cell: ManhwaImageCell, didLoadImageWithSize size: CGSize, atIndex index: Int)
    func manhwaImageCellDidRequestRetry(_ cell: ManhwaImageCell, atIndex index: Int)
}

final class ManhwaImageCell: UICollectionViewCell {
    static let reuseIdentifier = "ManhwaImageCell"

    weak var delegate: ManhwaImageCellDelegate?
    private(set) var index: Int = 0

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .black
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private let retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Tap to Retry", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setImage(UIImage(systemName: "exclamationmark.triangle"), for: .normal)
        button.tintColor = .white
        button.configuration = .plain()
        button.configuration?.imagePadding = 8
        button.configuration?.imagePlacement = .top
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()

    private var currentUrl: URL?
    private var loadedImageSize: CGSize?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.backgroundColor = .black
        contentView.addSubview(imageView)
        contentView.addSubview(loadingIndicator)
        contentView.addSubview(retryButton)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            retryButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            retryButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.kf.cancelDownloadTask()
        imageView.image = nil
        currentUrl = nil
        loadedImageSize = nil
        loadingIndicator.stopAnimating()
        retryButton.isHidden = true
    }

    func configure(with url: URL?, index: Int, options: KingfisherOptionsInfo) {
        self.index = index
        self.currentUrl = url

        guard let url = url else {
            showError()
            return
        }

        loadingIndicator.startAnimating()
        retryButton.isHidden = true

        imageView.kf.setImage(
            with: url,
            options: options
        ) { [weak self] result in
            guard let self = self else { return }

            self.loadingIndicator.stopAnimating()

            switch result {
            case .success(let imageResult):
                self.retryButton.isHidden = true
                let imageSize = imageResult.image.size
                self.loadedImageSize = imageSize
                self.delegate?.manhwaImageCell(self, didLoadImageWithSize: imageSize, atIndex: self.index)

            case .failure(let error):
                if case .requestError(reason: .emptyRequest) = error {
                    return
                }
                if !error.isTaskCancelled {
                    self.showError()
                }
            }
        }
    }

    private func showError() {
        retryButton.isHidden = false
        loadingIndicator.stopAnimating()
    }

    @objc private func retryTapped() {
        delegate?.manhwaImageCellDidRequestRetry(self, atIndex: index)
    }
}
