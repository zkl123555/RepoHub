# RepoHub

GitHub 开源项目浏览 App —— 独立设计并开发的 iOS 客户端，支持仓库搜索、列表浏览、详情查看与收藏。

## 功能

- 🔍 **仓库搜索** — 基于 GitHub REST API，支持实时输入防抖（0.3s）+ 请求取消，根治快速输入时的响应乱序问题
- 📜 **分页加载** — 滚动到底部前 5 行预加载下一页；`isLoadingMore` 标志位防重复请求；新数据增量 `insertRows`，列表不跳动
- ⭐ **收藏** — UserDefaults 持久化，App 重启后状态恢复；列表页与详情页通过「单一数据源 + 通知广播」实时同步
- 🕘 **搜索历史** — 去重置顶（最近搜索排最前）、上限 20 条；横滑胶囊标签点击直搜
- 🔄 **下拉刷新** + 边界状态 UI（空数据 / 网络错误 / 限流 403 差异化提示）

## 架构（MVVM）

```
View (ViewController / Cell)
  │  只管显示 + 转发事件，闭包订阅 VM 状态
  ▼
ViewModel (SearchViewModel / DetailViewModel)
  │  持有数据状态与业务逻辑，不 import UIKit（可脱离 UI 单测）
  ▼
Service (GitHubAPI / FavoritesStore / SearchHistoryStore)
  │  网络请求、本地存储
  ▼
Model (Repo / SearchResult, Codable)
```

数据流单向闭环：用户操作 → View 转发 → VM 调 Service → 结果回 VM 改状态 → 回调通知 View 刷新。ViewModel 对 View 无感知（View 订阅 VM，而非 VM 命令 View）。

## 技术要点

| 模块 | 实现 |
|---|---|
| 网络层 | URLSession 单例封装：统一 header/15s 超时；错误分类为 `APIError` 枚举；decode 失败降级不 crash；返回 `URLSessionDataTask` 支持取消 |
| 数据建模 | Codable + CodingKeys 映射蛇形命名（`stargazers_count` → `stargazersCount`）；可能缺失字段声明 optional |
| 列表性能 | Cell 复用 + `prepareForReuse` 取消头像下载任务并清空旧图，防复用错乱 |
| 持久化 | 收藏（模型转 JSON Data）、搜索历史（stringArray 直存）双落地 UserDefaults |
| 跨页同步 | `NotificationCenter` 广播，VM 桥接成回调，View 只面对 VM |
| 内存安全 | 回调闭包统一 `[weak self]`，避免 VC → VM → 闭包 → VC 引用环 |

## 环境

- iOS 15.0+ / Swift 5 / UIKit（纯代码布局，无第三方依赖）
- Xcode 打开 `RepoHub.xcodeproj`，选择 iPhone 模拟器，⌘R 运行
- 网络接口：GitHub Search API（`/search/repositories`），无需配置 token（匿名限流 10 次/分钟）

## 目录结构

```
RepoHub/
├── Models/Repo.swift                # Codable 数据模型
├── Networking/GitHubAPI.swift      # 网络封装（单例）
├── Services/
│   ├── FavoritesStore.swift        # 收藏存储
│   └── SearchHistoryStore.swift    # 搜索历史存储
├── ViewModels/
│   ├── SearchViewModel.swift       # 搜索/分页/防抖
│   └── DetailViewModel.swift       # 详情/收藏状态
└── Views/
    ├── SearchViewController.swift  # 搜索列表页
    ├── DetailViewController.swift  # 详情页
    └── RepoCell.swift              # 列表 Cell
```
