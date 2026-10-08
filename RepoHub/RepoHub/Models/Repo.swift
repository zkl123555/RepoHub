import Foundation

/// GitHub 仓库模型（Codable 解析 GitHub REST API 响应）
/// 关键点：GitHub API 的字段是蛇形命名（stargazers_count），
/// Swift 规范是驼峰（stargazersCount），用 CodingKeys 做映射
struct Repo: Codable {
    let id: Int
    let name: String                    // 仓库名
    let fullName: String                // "owner/repo" 全名
    let htmlURL: URL?
    let description: String?
    let stargazersCount: Int            // star 数
    let forksCount: Int                 // fork 数
    let language: String?               // 主要语言
    let owner: Owner

    struct Owner: Codable {
        let login: String
        let avatarURL: URL?

        enum CodingKeys: String, CodingKey {
            case login
            case avatarURL = "avatar_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case htmlURL = "html_url"
        case description
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case language
        case owner
    }
}

/// 搜索响应的外层结构：{ "total_count": ..., "items": [...] }
struct SearchResult: Codable {
    let totalCount: Int
    let items: [Repo]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case items
    }
}
