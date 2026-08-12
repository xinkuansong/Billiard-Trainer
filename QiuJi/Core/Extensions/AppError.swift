import Foundation

enum AppError: LocalizedError {
    case authFailed(String)
    case authRequired
    case networkError(String)
    /// 服务端返回的非 2xx。带上状态码，同步队列据此区分「永久失败（4xx，重试无意义）」
    /// 与「暂时失败（5xx，下次激活重试）」。
    case serverError(statusCode: Int, message: String)
    case invalidInput(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .authFailed(let msg): return msg
        case .authRequired: return "登录已过期，请重新登录"
        case .networkError(let msg): return msg
        case .serverError(_, let msg): return msg
        case .invalidInput(let msg): return msg
        case .unknown: return "发生未知错误，请重试"
        }
    }
}
