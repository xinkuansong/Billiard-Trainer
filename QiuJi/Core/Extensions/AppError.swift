import Foundation

enum AppError: LocalizedError {
    case authFailed(String)
    case authRequired
    case networkError(String)
    case serverError(String)
    case invalidInput(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .authFailed(let msg): return msg
        case .authRequired: return "登录已过期，请重新登录"
        case .networkError(let msg): return msg
        case .serverError(let msg): return msg
        case .invalidInput(let msg): return msg
        case .unknown: return "发生未知错误，请重试"
        }
    }
}
