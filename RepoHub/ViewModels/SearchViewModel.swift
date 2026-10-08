import Foundation

/// 搜索页 ViewModel
/// MVVM 核心：不 import UIKit（View 层不可见），只暴露数据和状态给 View 订阅
/// 职责：搜索请求、分页加载、防抖、收藏状态维护
final class SearchViewModel {

    // MARK: - 输出给 View 的状态

    private(set) var repos: [Repo] = []           // 列表数据源
    private(set) var isLoading = false            // 下拉/首屏加载中
    private(set) var isLoadingMore = false        // 分页加载中
    private(set) var canLoadMore = true            // 是否还有下一页
    private var currentPage = 1
    private var currentQuery = ""

    /// 列表刷新回调（View 订阅）
    var onDataReload: (() -> Void)?
    /// 追加加载回调（分页只刷新新增行）
    var onDataAppended: ((_ startIndex: Int, _ count: Int) -> Void)?
    /// 状态文案回调（loading / 空 / 错误）
    var onStateChanged: ((String?) -> Void)?
    /// 下拉刷新结束回调
    var onRefreshEnd: (() -> Void)?

    // MARK: - 防抖（专有名词 debouncing）

    private var searchTask: URLSessionDataTask?
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceDelay: TimeInterval = 0.3

    /// 搜索框连续输入时调用：取消上一次待发请求，等安静 0.3s 才真正发
    func searchTextFieldDidChange(_ text: String) {
        debounceWorkItem?.cancel()                          // 取消上一次的"延迟触发"
        searchTask?.cancel()                                // 取消上一次真正发出的请求（根治响应乱序）
        debounceWorkItem = DispatchWorkItem { [weak self] in
            self?.startSearch(text)
        }
        if let workItem = debounceWorkItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
        }
    }

    // MARK: - 搜索与分页

    /// 发起新搜索（第 1 页）
    func startSearch(_ query: String) {
        guard !query.isEmpty else {
            repos = []
            onDataReload?()
            onStateChanged?("输入关键字开始搜索")
            return
        }
        currentQuery = query
        currentPage = 1
        canLoadMore = false
        searchTask?.cancel()

        isLoading = true
        onStateChanged?(nil)

        searchTask = GitHubAPI.shared.searchRepos(query: query, page: currentPage) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            switch result {
            case .success(let searchResult):
                self.repos = searchResult.items
                self.canLoadMore = !searchResult.items.isEmpty
                self.onDataReload?()
                self.onStateChanged?(searchResult.items.isEmpty ? "没有找到相关仓库" : nil)
            case .failure(let error):
                self.repos = []
                self.onDataReload?()
                self.onStateChanged?(error.errorDescription)
            }
        }
    }

    /// 加载下一页（滚动到底部附近触发）
    /// 注意 isLoadingMore 防重复触发：请求进行中不再发第二次
    func loadMore() {
        guard !isLoadingMore, canLoadMore, !currentQuery.isEmpty else { return }
        isLoadingMore = true
        GitHubAPI.shared.searchRepos(query: currentQuery, page: currentPage + 1) { [weak self] result in
            guard let self = self else { return }
            self.isLoadingMore = false
            switch result {
            case .success(let searchResult):
                self.currentPage += 1
                let startIndex = self.repos.count
                self.repos.append(contentsOf: searchResult.items)   // append 到原数组
                self.canLoadMore = !searchResult.items.isEmpty
                // 只刷新新增的行，不整表 reloadData
                self.onDataAppended?(startIndex, searchResult.items.count)
            case .failure:
                self.canLoadMore = true   // 失败了允许重试
            }
        }
    }

    /// 下拉刷新：重新搜当前关键字
    func refresh() {
        guard !currentQuery.isEmpty else {
            onRefreshEnd?()
            return
        }
        startSearch(currentQuery)
        onRefreshEnd?()
    }
}
