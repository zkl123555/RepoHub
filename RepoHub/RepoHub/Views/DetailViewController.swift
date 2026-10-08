import UIKit

/// 详情页：展示仓库信息 + 收藏切换
final class DetailViewController: UIViewController {

    private let viewModel: DetailViewModel

    private let scrollView = UIScrollView()
    private let contentView = UIStackView()

    private let favoriteButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "☆ 收藏"
        config.cornerStyle = .capsule
        let button = UIButton(configuration: config)
        return button
    }()

    init(repo: Repo) {
        self.viewModel = DetailViewModel(repo: repo)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        updateFavoriteUI()
    }

    private func setupUI() {
        title = viewModel.title

        view.backgroundColor = .systemBackground
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scrollView)

        contentView.axis = .vertical
        contentView.spacing = 16
        contentView.isLayoutMarginsRelativeArrangement = true
        contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 24, leading: 20, bottom: 24, trailing: 20)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        // 信息卡片
        let infoStack = UIStackView(arrangedSubviews: [
            makeTitleLabel(viewModel.title),
            makeBodyLabel(viewModel.descriptionText),
            makeMetaRow()
        ])
        infoStack.axis = .vertical
        infoStack.spacing = 10
        infoStack.isLayoutMarginsRelativeArrangement = true
        infoStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        infoStack.layer.cornerRadius = 12
        infoStack.backgroundColor = .secondarySystemBackground
        contentView.addArrangedSubview(infoStack)

        // 用浏览器打开仓库
        let openButton = UIButton(type: .system)
        openButton.setTitle("在 GitHub 中打开 ↗", for: .normal)
        openButton.addTarget(self, action: #selector(openInSafari), for: .touchUpInside)
        contentView.addArrangedSubview(openButton)

        // 收藏按钮
        favoriteButton.addTarget(self, action: #selector(toggleFavorite), for: .touchUpInside)
        contentView.addArrangedSubview(favoriteButton)
    }

    private func bindViewModel() {
        viewModel.observeFavorites()
        viewModel.onFavoriteStateChanged = { [weak self] favorited in
            self?.updateFavoriteUI()
        }
    }

    private func updateFavoriteUI() {
        var config = favoriteButton.configuration
        config?.title = viewModel.isFavorited ? "★ 已收藏" : "☆ 收藏"
        config?.baseBackgroundColor = viewModel.isFavorited ? .systemOrange : .systemBlue
        favoriteButton.configuration = config
    }

    // MARK: - 事件

    @objc private func toggleFavorite() {
        viewModel.toggleFavorite()
    }

    @objc private func openInSafari() {
        if let url = viewModel.repo.htmlURL {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - 小工具

    private func makeTitleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.numberOfLines = 0
        return label
    }

    private func makeBodyLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }

    private func makeMetaRow() -> UILabel {
        let label = UILabel()
        label.text = "⭐ \(viewModel.starsText)   🍴 \(viewModel.forksText)   💬 \(viewModel.languageText)"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .tertiaryLabel
        return label
    }
}
