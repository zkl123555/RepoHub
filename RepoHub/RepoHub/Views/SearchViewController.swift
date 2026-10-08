import UIKit

/// 搜索页：搜索框 + 收藏入口 + 仓库列表（下拉刷新 / 上滑分页）
/// View 层职责：只管显示与转发事件，数据逻辑全在 SearchViewModel
final class SearchViewController: UIViewController {

    private let viewModel = SearchViewModel()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.dataSource = self
        tv.delegate = self
        tv.register(RepoCell.self, forCellReuseIdentifier: RepoCell.identifier)
        tv.refreshControl = UIRefreshControl()   // 下拉刷新
        tv.refreshControl?.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        tv.keyboardDismissMode = .onDrag         // 滑动列表时收起键盘
        return tv
    }()

    private lazy var searchController: UISearchController = {
        let sc = UISearchController(searchResultsController: nil)
        sc.searchBar.placeholder = "搜索 GitHub 仓库，如 swift"
        sc.obscuresBackgroundDuringPresentation = false
        sc.searchBar.delegate = self
        return sc
    }()

    /// 状态提示（空数据/错误文案）
    private let stateLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        return label
    }()

    /// 搜索历史标签行：横向滚动的胶囊按钮
    private let historyRow: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 8
        sv.alignment = .center
        return sv
    }()

    /// 历史区外层：标题 + 标签行 + 清空按钮，包在 scrollView 里支持横滑
    private let historyContainer = UIView()
    private let historyScrollView = UIScrollView()
    private let historyTitleLabel = UILabel()

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()   // 订阅 VM 的输出（MVVM：View 订阅，不是 VM 命令 View）
        stateLabel.text = "输入关键字开始搜索"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 返回本页时刷新收藏状态（从详情页收藏后回来 ❤️ 同步）
        // —— 跨页状态同步最简单的实现：出现时重读
        if viewModel.repos.isEmpty == false {
            tableView.reloadData()
        }
    }

    private func setupUI() {
        // 搜索框挂到导航栏的标准属性（iOS 11+）：自动获得下拉时收起、大标题折叠等系统行为
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false   // 列表页常驻显示搜索框
        view.addSubview(tableView)
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        stateLabel.frame = CGRect(x: 24, y: 120, width: view.bounds.width - 48, height: 60)
        stateLabel.autoresizingMask = [.flexibleWidth]
        view.addSubview(stateLabel)

        setupHistoryRow()
    }

    /// 历史标签行：标题 + 清空按钮 + 横滑标签
    private func setupHistoryRow() {
        historyContainer.frame = CGRect(x: 0, y: 120, width: view.bounds.width, height: 100)
        historyContainer.autoresizingMask = [.flexibleWidth]
        historyContainer.backgroundColor = .systemBackground

        historyTitleLabel.text = "搜索历史"
        historyTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        historyTitleLabel.textColor = .secondaryLabel

        let clearButton = UIButton(type: .system)
        clearButton.setTitle("清空", for: .normal)
        clearButton.titleLabel?.font = .systemFont(ofSize: 13)
        clearButton.addTarget(self, action: #selector(clearHistoryTapped), for: .touchUpInside)

        let titleRow = UIStackView(arrangedSubviews: [historyTitleLabel, clearButton])
        titleRow.axis = .horizontal
        titleRow.distribution = .equalSpacing
        titleRow.frame = CGRect(x: 16, y: 8, width: view.bounds.width - 32, height: 24)

        historyScrollView.frame = CGRect(x: 16, y: 36, width: view.bounds.width - 32, height: 44)
        historyScrollView.showsHorizontalScrollIndicator = false
        historyScrollView.addSubview(historyRow)
        // stack 内容自适应，scrollView 靠 contentSize 滚动
        historyRow.frame = CGRect(x: 0, y: 8, width: max(200, viewModel.searchHistory.count * 120), height: 28)

        historyContainer.addSubview(titleRow)
        historyContainer.addSubview(historyScrollView)
        view.addSubview(historyContainer)
        historyContainer.isHidden = true   // 初始无历史时不占位
    }

    /// 根据最新历史数据重建标签
    private func rebuildHistoryTags() {
        historyRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let keywords = viewModel.searchHistory
        historyContainer.isHidden = keywords.isEmpty

        for keyword in keywords {
            var config = UIButton.Configuration.filled()
            config.title = keyword
            config.cornerStyle = .capsule
            config.baseBackgroundColor = .secondarySystemBackground
            config.baseForegroundColor = .label
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
            let button = UIButton(configuration: config)
            button.addTarget(self, action: #selector(historyTagTapped(_:)), for: .touchUpInside)
            historyRow.addArrangedSubview(button)
        }
        historyRow.frame.size.width = max(CGFloat(keywords.count) * 120, 200)
        historyScrollView.contentSize = CGSize(width: historyRow.frame.width, height: 44)
    }

    // MARK: - 绑定 ViewModel

    private func bindViewModel() {
        viewModel.onDataReload = { [weak self] in
            self?.tableView.reloadData()
            self?.stateLabel.isHidden = !(self?.viewModel.repos.isEmpty ?? true)
        }
        viewModel.onDataAppended = { [weak self] startIndex, count in
            // 分页只插新增行，避免整表 reload 造成跳动
            let indexPaths = (startIndex..<(startIndex + count)).map { IndexPath(row: $0, section: 0) }
            self?.tableView.insertRows(at: indexPaths, with: .none)
        }
        viewModel.onStateChanged = { [weak self] message in
            if let message = message {
                self?.stateLabel.text = message
                self?.stateLabel.isHidden = false
            } else {
                self?.stateLabel.isHidden = true
            }
        }
        viewModel.onRefreshEnd = { [weak self] in
            self?.tableView.refreshControl?.endRefreshing()
        }
        // 历史变更 → 重建标签行（VM 把 Store 的通知桥接成了回调，View 只面对 VM）
        viewModel.onHistoryChanged = { [weak self] in
            self?.rebuildHistoryTags()
        }
        rebuildHistoryTags()   // 首次进入展示已有历史
    }

    // MARK: - 事件

    @objc private func pullToRefresh() {
        viewModel.refresh()
    }

    /// 点历史标签 = 直接用该关键字搜索（搜索框也同步填上）
    @objc private func historyTagTapped(_ sender: UIButton) {
        // Configuration 方式创建的按钮，title 存在 configuration 里，
        // 传统 currentTitle 取出来是 nil（踩过的坑）
        guard let keyword = sender.configuration?.title else { return }
        searchController.searchBar.text = keyword
        searchController.isActive = true
        viewModel.startSearch(keyword)
        // 搜索出结果后历史行藏起来，把屏幕让给列表
        historyContainer.isHidden = true
    }

    @objc private func clearHistoryTapped() {
        viewModel.clearHistory()
    }
}

// MARK: - UITableViewDataSource / Delegate

extension SearchViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.repos.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RepoCell.identifier, for: indexPath)
        if let repoCell = cell as? RepoCell {
            repoCell.configure(with: viewModel.repos[indexPath.row])
        }
        return cell
    }

    /// 分页触发：滚到底部前 5 行就预加载（比滚到底才加载体验更顺）
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let lastRow = viewModel.repos.count - 1
        if indexPath.row >= lastRow - 5 {
            viewModel.loadMore()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let repo = viewModel.repos[indexPath.row]
        navigationController?.pushViewController(DetailViewController(repo: repo), animated: true)
    }
}

// MARK: - UISearchBarDelegate

extension SearchViewController: UISearchBarDelegate {

    /// 每敲一个字都会进这里——里面做防抖（去 ViewModel 看实现）
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        viewModel.searchTextFieldDidChange(searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        viewModel.startSearch(searchBar.text ?? "")
        historyContainer.isHidden = true   // 出结果后历史行让位
    }

    /// 点到搜索框准备输入时，把历史行亮出来方便点选
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        rebuildHistoryTags()
        return true
    }
}
