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
        navigationItem.titleView = searchController
        view.addSubview(tableView)
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        stateLabel.frame = CGRect(x: 24, y: 120, width: view.bounds.width - 48, height: 60)
        stateLabel.autoresizingMask = [.flexibleWidth]
        view.addSubview(stateLabel)
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
    }

    // MARK: - 事件

    @objc private func pullToRefresh() {
        viewModel.refresh()
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
    }
}
