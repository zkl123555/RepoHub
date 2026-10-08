import Foundation

/// 搜索历史本地存储：UserDefaults 键值仓库
/// 设计要点：
/// 1. 历史是轻量字符串数组，UserDefaults 场景合适
/// 2. 去重置顶：重复搜索的关键字挪到最前（跟手机输入法的历史词一个逻辑）
/// 3. 上限 20 条：防止无限增长撑大 plist
/// 4. 变更广播与 FavoritesStore 同一套模式（单一数据源 + 通知同步）
final class SearchHistoryStore {

    static let shared = SearchHistoryStore()

    /// 历史变更广播：列表页监听后刷新历史入口
    static let historyDidChange = Notification.Name("SearchHistoryDidChange")

    private let key = "search_history"
    private let defaults = UserDefaults.standard
    private let maxCount = 20

    private init() {}

    // MARK: - 读写

    func allHistory() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    /// 记录一次搜索：去重 + 最新排最前 + 截断到上限
    func record(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = allHistory()
        list.removeAll { $0 == trimmed }          // 已存在的先删掉（去重）
        list.insert(trimmed, at: 0)               // 最新排最前
        if list.count > maxCount {
            list = Array(list.prefix(maxCount))    // 超出上限截断旧的
        }
        defaults.set(list, forKey: key)
        NotificationCenter.default.post(name: Self.historyDidChange, object: nil)
    }

    /// 清空历史
    func removeAll() {
        defaults.removeObject(forKey: key)
        NotificationCenter.default.post(name: Self.historyDidChange, object: nil)
    }
}
