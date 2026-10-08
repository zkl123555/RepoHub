import Foundation

/// 收藏本地存储：UserDefaults 键值仓库
/// 设计要点：
/// 1. UserDefaults 只适合轻量偏好数据——收藏存的是 [仓库名+id]，体积小，符合场景
/// 2. 存储结构转 JSON Data 再写入（UserDefaults 只收基本类型/Data）
/// 3. 变更后广播通知，列表页/详情页监听同步收藏状态（跨页状态同步）
final class FavoritesStore {

    static let shared = FavoritesStore()

    /// 收藏变更广播：任何页面监听此通知即可同步 ❤️ 状态
    static let favoritesDidChange = Notification.Name("FavoritesDidChange")

    private let key = "favorited_repos"
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - 读写

    private func load() -> [Repo] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Repo].self, from: data)) ?? []
    }

    private func save(_ repos: [Repo]) {
        guard let data = try? JSONEncoder().encode(repos) else { return }
        defaults.set(data, forKey: key)
        // 广播：状态变了，各页面自己决定怎么刷
        NotificationCenter.default.post(name: Self.favoritesDidChange, object: nil)
    }

    // MARK: - 对外接口

    func isFavorited(_ repo: Repo) -> Bool {
        load().contains { $0.id == repo.id }
    }

    /// 返回 true = 收藏后状态，false = 取消后状态
    @discardableResult
    func toggle(_ repo: Repo) -> Bool {
        var repos = load()
        if let index = repos.firstIndex(where: { $0.id == repo.id }) {
            repos.remove(at: index)
            save(repos)
            return false
        } else {
            repos.insert(repo, at: 0)   // 最新收藏排最前
            save(repos)
            return true
        }
    }

    func allFavorites() -> [Repo] {
        load()
    }
}
