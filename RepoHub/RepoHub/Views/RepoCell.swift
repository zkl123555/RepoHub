import UIKit

/// 仓库列表 Cell：自定义布局（头像 + 名称 + 描述 + star/fork/语言）
/// 复用要点：prepareForReuse 里清空旧数据——防复用错乱（老手必答）
final class RepoCell: UITableViewCell {

    static let identifier = "RepoCell"

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 8
        iv.backgroundColor = UIColor.secondarySystemBackground
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        return label
    }()

    private let metaLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        return label
    }()

    private var avatarLoadTask: URLSessionDataTask?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        accessoryType = .disclosureIndicator
        let stack = UIStackView(arrangedSubviews: [nameLabel, descriptionLabel, metaLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(avatarImageView)
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 44),
            avatarImageView.heightAnchor.constraint(equalToConstant: 44),

            stack.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    /// 复用前的清理：cell 从复用池捞出来时执行
    /// 这一步不做，头像/文案会闪现上一条的数据（复用错乱 bug 的修法）
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarLoadTask?.cancel()     // 取消上一条还在下载的头像请求
        avatarImageView.image = nil  // 清旧图
        nameLabel.text = nil
        descriptionLabel.text = nil
        metaLabel.text = nil
    }

    func configure(with repo: Repo) {
        nameLabel.text = repo.fullName
        descriptionLabel.text = repo.description
        metaLabel.text = "⭐ \(repo.stargazersCount)   🍴 \(repo.forksCount)   \(repo.language ?? "")"
        loadAvatar(url: repo.owner.avatarURL)
    }

    private func loadAvatar(url: URL?) {
        guard let url = url else { return }
        avatarLoadTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.avatarImageView.image = image
            }
        }
        avatarLoadTask?.resume()
    }
}
