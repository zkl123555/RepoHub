import Foundation

/// 网络错误统一分类：封装层把错误归好类，View 层只管展示对应文案
enum APIError: Error, LocalizedError {
    case invalidURL            // URL 拼不出来
    case networkFailed(Error)  // 系统层网络错误（无网/超时/DNS）
    case serverError(Int)      // HTTP 非 2xx（403 限流 / 500 等）
    case decodingFailed        // JSON 解析失败（脏数据）
    case emptyResponse        // 无数据

    var errorDescription: String? {
        switch self {
        case .invalidURL:       return "请求地址无效"
        case .networkFailed:    return "网络连接失败，请检查网络"
        case .serverError(let code):
            return code == 403 ? "请求过于频繁，请稍后再试" : "服务器错误(\(code))"
        case .decodingFailed:   return "数据解析失败"
        case .emptyResponse:    return "没有找到相关仓库"
        }
    }
}

/// GitHub REST API 请求封装
/// 设计要点：
/// 1. 统一入口：baseURL / header / 超时只写一次，业务层不重复
/// 2. 错误在封装层分类，调用方拿到的是归好类的 APIError
/// 3. decode 失败降级（抛错而不是崩溃），脏数据不炸整个列表
/// 4. 支持"可取消"：返回 URLSessionDataTask，防抖时 cancel 上一次请求
final class GitHubAPI {

    static let shared = GitHubAPI()

    private let session: URLSession
    private let baseURL = "https://api.github.com"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15   // 超时统一 15 秒
        config.httpAdditionalHeaders = [
            "Accept": "application/vnd.github+json"
        ]
        session = URLSession(configuration: config)
    }

    /// 搜索仓库（第 1 页起，每页 30 条——分页由服务端控制）
    /// - Returns: URLSessionDataTask（调用方可 cancel，用于搜索防抖）
    @discardableResult
    func searchRepos(query: String,
                     page: Int,
                     completion: @escaping (Result<SearchResult, APIError>) -> Void) -> URLSessionDataTask? {
        // 1. URL 拼装与转义（query 里有空格/中文必须 percentEncoded）
        guard var components = URLComponents(string: baseURL + "/search/repositories") else {
            completion(.failure(.invalidURL))
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: "30")
        ]
        guard let url = components.url else {
            completion(.failure(.invalidURL))
            return nil
        }

        // 2. 发请求
        let task = session.dataTask(with: url) { data, response, error in
            // 3. 网络层错误
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(.networkFailed(error)))
                }
                return
            }
            // 4. HTTP 状态码检查
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(.emptyResponse)) }
                return
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async { completion(.failure(.serverError(httpResponse.statusCode))) }
                return
            }
            // 5. JSON 解码（Codable + CodingKeys 映射）
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(.emptyResponse)) }
                return
            }
            do {
                let result = try JSONDecoder().decode(SearchResult.self, from: data)
                DispatchQueue.main.async { completion(.success(result)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(.decodingFailed)) }
            }
        }
        task.resume()
        return task
    }
}
