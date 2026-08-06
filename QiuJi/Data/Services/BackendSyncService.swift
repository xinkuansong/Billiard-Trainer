import Foundation
import SwiftData

// MARK: - DTOs

struct TrainingSessionDTO: Codable {
    let clientId: String
    let date: Date
    let ballType: String
    let totalDurationMinutes: Int
    let note: String
    let planId: String?
    /// 会话分类（契约 §5.3）。`tool` 会话上传即靠此字段被后端区分（D-v29-4）。
    let kind: String
    let drillEntries: [DrillEntryDTO]

    struct DrillEntryDTO: Codable {
        let drillId: String
        let drillNameZh: String
        let sets: [DrillSetDTO]
    }

    struct DrillSetDTO: Codable {
        let setNumber: Int
        let targetBalls: Int
        let madeBalls: Int
    }

    init(from session: TrainingSession) {
        self.clientId = session.id.uuidString
        self.date = session.date
        self.ballType = session.ballType
        self.totalDurationMinutes = session.totalDurationMinutes
        self.note = session.note
        self.planId = session.planId
        self.kind = session.kind
        self.drillEntries = session.drillEntries.map { entry in
            DrillEntryDTO(
                drillId: entry.drillId,
                drillNameZh: entry.drillNameZh,
                sets: entry.sets.map { s in
                    DrillSetDTO(setNumber: s.setNumber, targetBalls: s.targetBalls, madeBalls: s.madeBalls)
                }
            )
        }
    }

    /// 同一 DTO 既用于请求体也用于解析响应，而后端 Mongoose schema 默认 `strict: true`
    /// ——旧版后端不认识的字段会被丢弃，回包里就没有它。若把新增字段声明成必填，
    /// 解码就会抛错 → `syncSession` 视为上传失败 → 队列项永不出队、无限重试。
    /// 故新增字段一律 `decodeIfPresent` + 默认值，保持对旧后端的向前兼容。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clientId = try c.decode(String.self, forKey: .clientId)
        date = try c.decode(Date.self, forKey: .date)
        ballType = try c.decodeIfPresent(String.self, forKey: .ballType) ?? "chinese8"
        totalDurationMinutes = try c.decodeIfPresent(Int.self, forKey: .totalDurationMinutes) ?? 0
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        planId = try c.decodeIfPresent(String.self, forKey: .planId)
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? TrainingSessionKind.drill
        drillEntries = try c.decodeIfPresent([DrillEntryDTO].self, forKey: .drillEntries) ?? []
    }
}

struct AngleTestDTO: Codable {
    let clientId: String
    let date: Date
    let actualAngle: Double
    let userAngle: Double
    let pocketType: String
    /// 题型（v29.1 登记项 / 契约 §8.13）：缺了它服务端无法区分角度类与瞄准点类成绩。
    let quizType: String
    /// 瞄准点训练的有符号毫米误差（契约 §8.13）。角度类恒为 0。
    let errorMM: Double
    /// 归属的 `kind="cognitive"` 会话（契约 §5.3）。历史数据回填前为 nil。
    let sessionId: String?

    init(from result: AngleTestResult) {
        self.clientId = result.id.uuidString
        self.date = result.date
        self.actualAngle = result.actualAngle
        self.userAngle = result.userAngle
        self.pocketType = result.pocketType
        self.quizType = result.quizType
        self.errorMM = result.errorMM
        self.sessionId = result.sessionId?.uuidString
    }

    /// 与 `TrainingSessionDTO` 同理：新增字段容忍旧后端回包缺字段，避免解码失败被
    /// 误判成上传失败而无限重试。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clientId = try c.decode(String.self, forKey: .clientId)
        date = try c.decode(Date.self, forKey: .date)
        actualAngle = try c.decode(Double.self, forKey: .actualAngle)
        userAngle = try c.decode(Double.self, forKey: .userAngle)
        pocketType = try c.decode(String.self, forKey: .pocketType)
        quizType = try c.decodeIfPresent(String.self, forKey: .quizType) ?? "table2D"
        errorMM = try c.decodeIfPresent(Double.self, forKey: .errorMM) ?? 0
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
    }
}

struct UserDTO: Codable {
    let id: String
    let displayName: String?
    let email: String?
    let provider: String
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: UserDTO
}

struct BatchResult: Codable {
    let upserted: Int
    let modified: Int
}

// MARK: - Service

actor BackendSyncService {
    static let shared = BackendSyncService()
    private let api = APIClient.shared

    // MARK: - Auth

    func loginWithApple(identityToken: String) async throws -> AuthResponse {
        struct Req: Encodable { let identityToken: String }
        let res: AuthResponse = try await api.request(
            Endpoint(.post, "/auth/login-apple", body: Req(identityToken: identityToken))
        )
        KeychainService.save(key: .accessToken, value: res.accessToken)
        KeychainService.save(key: .refreshToken, value: res.refreshToken)
        return res
    }

    func logout() async {
        let _: EmptyResponse? = try? await api.request(Endpoint(.delete, "/auth/logout"))
        KeychainService.clearAll()
    }

    // MARK: - Training Sessions

    func syncSession(_ session: TrainingSession) async throws {
        let dto = TrainingSessionDTO(from: session)
        let _: TrainingSessionDTO = try await api.request(
            Endpoint(.post, "/training-sessions", body: dto)
        )
    }

    func fetchSessionsAfter(_ date: Date?) async throws -> [TrainingSessionDTO] {
        var query: [URLQueryItem] = []
        if let date {
            query.append(URLQueryItem(name: "after", value: ISO8601DateFormatter().string(from: date)))
        }
        return try await api.request(Endpoint(.get, "/training-sessions", query: query))
    }

    func migrateLocalSessions(_ sessions: [TrainingSession]) async throws -> BatchResult {
        let dtos = sessions.map { TrainingSessionDTO(from: $0) }
        return try await api.request(Endpoint(.post, "/training-sessions/batch", body: dtos))
    }

    // MARK: - Angle Tests

    func syncAngleTest(_ result: AngleTestResult) async throws {
        let dto = AngleTestDTO(from: result)
        let _: AngleTestDTO = try await api.request(
            Endpoint(.post, "/angle-tests", body: dto)
        )
    }

    // MARK: - User

    func deleteAccount() async throws {
        let _: EmptyResponse = try await api.request(Endpoint(.delete, "/user/account"))
        KeychainService.clearAll()
    }
}
