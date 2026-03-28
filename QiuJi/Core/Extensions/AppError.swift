import Foundation

enum AppError: LocalizedError {
    case authFailed(String)
    case networkError(String)
    case invalidInput(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .authFailed(let msg): return msg
        case .networkError(let msg): return msg
        case .invalidInput(let msg): return msg
        case .unknown: return "发生未知错误，请重试"
        }
    }
}
