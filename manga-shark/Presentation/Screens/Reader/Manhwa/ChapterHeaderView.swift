import UIKit

/// Supplementary view displayed at chapter boundaries in infinite scroll
final class ChapterHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "ChapterHeaderView"
    static let height: CGFloat = 44

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let topSeparator: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let bottomSeparator: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .black
        addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(topSeparator)
        containerView.addSubview(bottomSeparator)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            topSeparator.topAnchor.constraint(equalTo: containerView.topAnchor),
            topSeparator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            topSeparator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            topSeparator.heightAnchor.constraint(equalToConstant: 1),

            bottomSeparator.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            bottomSeparator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            bottomSeparator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            bottomSeparator.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    func configure(with title: String) {
        titleLabel.text = title
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
    }
}
