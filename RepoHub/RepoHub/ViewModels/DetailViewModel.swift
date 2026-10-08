import Foundation

/// 详情页 ViewModel：展示单个仓库信息 + 收藏状态管理
final class DetailViewModel {

    let repo: Repo

    /// View 订阅：收藏状态变化时刷新按钮
    var onFavoriteStateChanged: ((Bool) -> Void)?

    init(repo: Repo) {
        self.repo = repo
    }

    var title: String { repo.fullName }
    var descriptionText: String { repo.description ?? "暂无描述" }
    var languageText: String { repo.language ?? "Unknown" }
    var starsText: String { "\(repo.stargazersCount)" }
    var forksText: String { "\(repo.forksCount)" }

    /// 当前是否已收藏
    var isFavorited: Bool {
        FavoritesStore.shared.isFavorited(repo)
    }

    /// 点击收藏按钮：切换状态 + 通知 View
    func toggleFavorite() {
        let favorited = FavoritesStore.shared.toggle(repo)
        onFavoriteStateChanged?(favorited)
    }

    /// 订阅全局收藏变更（详情页打开时列表页也可能改了收藏——单一数据源思想：
    /// 两页都从 FavoritesStore 这一份存储读状态，谁变了靠通知同步）
    func observeFavorites() {
        NotificationCenter.default.addObserver(
            forName: FavoritesStore.favoritesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onFavoriteStateChanged?(self?.isFavorited ?? false)
        }
    }
}
