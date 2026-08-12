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
        /// 训练内顺序（契约 §4.1）。旧库/旧后端回包统一为 0。
        let orderIndex: Int
        /// 该 drill 的训练心得（契约 §8.7）。
        let note: String
        /// 达标说明快照，人类可读（契约 §6.5：写入即冻结）。
        let criteriaText: String
        let sets: [DrillSetDTO]

        init(drillId: String, drillNameZh: String,
             orderIndex: Int = 0, note: String = "", criteriaText: String = "",
             sets: [DrillSetDTO]) {
            self.drillId = drillId
            self.drillNameZh = drillNameZh
            self.orderIndex = orderIndex
            self.note = note
            self.criteriaText = criteriaText
            self.sets = sets
        }

        /// 见 `TrainingSessionDTO.init(from:)` 的前向兼容说明：新增字段一律
        /// `decodeIfPresent` + 默认值，旧后端回包缺字段不得让整条解码抛错。
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            drillId = try c.decode(String.self, forKey: .drillId)
            drillNameZh = try c.decodeIfPresent(String.self, forKey: .drillNameZh) ?? ""
            orderIndex = try c.decodeIfPresent(Int.self, forKey: .orderIndex) ?? 0
            note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
            criteriaText = try c.decodeIfPresent(String.self, forKey: .criteriaText) ?? ""
            sets = try c.decodeIfPresent([DrillSetDTO].self, forKey: .sets) ?? []
        }
    }

    struct DrillSetDTO: Codable {
        let setNumber: Int
        let targetBalls: Int
        let madeBalls: Int
        /// 球形归属（契约 §4.1）。单球形 drill 与旧库为 nil。
        let formationToken: String?
        /// 球形显示名快照（契约 §6.5：写入即冻结）。
        let formationName: String?
        /// made/target 的单位语义（契约 §5.2）："球" | "局" | "次"。
        /// 丢失会让恢复数据语义错误（「局/次」被当「球」），故默认取本地模型同款 "球"。
        let unitLabel: String
        /// 达标线快照（契约 §5.5）。0/0 表示「未设定」。
        let passMade: Int
        let passTotal: Int
        /// 每组用时（契约 §8.7）。未采集为 nil。
        let durationSeconds: Int?

        init(setNumber: Int, targetBalls: Int, madeBalls: Int,
             formationToken: String? = nil, formationName: String? = nil,
             unitLabel: String = "球", passMade: Int = 0, passTotal: Int = 0,
             durationSeconds: Int? = nil) {
            self.setNumber = setNumber
            self.targetBalls = targetBalls
            self.madeBalls = madeBalls
            self.formationToken = formationToken
            self.formationName = formationName
            self.unitLabel = unitLabel
            self.passMade = passMade
            self.passTotal = passTotal
            self.durationSeconds = durationSeconds
        }

        /// 同 `DrillEntryDTO`：新增字段容忍旧后端回包缺字段。
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            setNumber = try c.decodeIfPresent(Int.self, forKey: .setNumber) ?? 0
            targetBalls = try c.decodeIfPresent(Int.self, forKey: .targetBalls) ?? 0
            madeBalls = try c.decodeIfPresent(Int.self, forKey: .madeBalls) ?? 0
            formationToken = try c.decodeIfPresent(String.self, forKey: .formationToken)
            formationName = try c.decodeIfPresent(String.self, forKey: .formationName)
            unitLabel = try c.decodeIfPresent(String.self, forKey: .unitLabel) ?? "球"
            passMade = try c.decodeIfPresent(Int.self, forKey: .passMade) ?? 0
            passTotal = try c.decodeIfPresent(Int.self, forKey: .passTotal) ?? 0
            durationSeconds = try c.decodeIfPresent(Int.self, forKey: .durationSeconds)
        }
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
                orderIndex: entry.orderIndex,
                note: entry.note,
                criteriaText: entry.criteriaText,
                sets: entry.sets.map { s in
                    DrillSetDTO(
                        setNumber: s.setNumber,
                        targetBalls: s.targetBalls,
                        madeBalls: s.madeBalls,
                        formationToken: s.formationToken,
                        formationName: s.formationName,
                        unitLabel: s.unitLabel,
                        passMade: s.passMade,
                        passTotal: s.passTotal,
                        durationSeconds: s.durationSeconds
                    )
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

    /// 取 DTO 而非 `TrainingSession`：`@Model` 对象绑定在 MainActor 的 ModelContext 上，
    /// 由调用方在自己的 actor 上快照成 DTO 再跨界，避免在本 actor 内读取模型对象。
    func uploadSession(_ dto: TrainingSessionDTO) async throws {
        let _: TrainingSessionDTO = try await api.request(
            Endpoint(.post, "/training-sessions", body: dto)
        )
    }

    /// 按客户端 UUID 硬删服务端副本（v36 D-v36-2）。客户端不持有 Mongo `_id`，
    /// 故走 `by-client` 端点；该端点对「本就不存在」也返回 2xx（删除语义幂等）。
    func deleteSession(clientId: String) async throws {
        let _: EmptyResponse = try await api.request(
            Endpoint(.delete, "/training-sessions/by-client/\(clientId)")
        )
    }

    /// 下行恢复的拉取入口（v36 W3）。返回信封而非裸 DTO：增量锚点必须用服务端
    /// `updatedAt`（后端过滤条件就是 `updatedAt > after`），而 `updatedAt` 是传输层
    /// 元数据、不进业务 DTO（W1 已定稿其字段集）。
    ///
    /// `after` 用 `ISO8601DateFormatter` 输出（无小数秒），相当于把锚点向下取整到秒：
    /// 边界记录可能被重复返回，而合并按 clientId 幂等，重复不产生重复实体；
    /// 反方向（向上取整）才会漏数据，故这里的取整方向是安全的那一侧。
    func fetchSessionsAfter(_ date: Date?) async throws -> [SyncedRecord<TrainingSessionDTO>] {
        try await api.request(Endpoint(.get, "/training-sessions", query: Self.afterQuery(date)))
    }

    private static func afterQuery(_ date: Date?) -> [URLQueryItem] {
        guard let date else { return [] }
        return [URLQueryItem(name: "after", value: ISO8601DateFormatter().string(from: date))]
    }

    func migrateLocalSessions(_ sessions: [TrainingSession]) async throws -> BatchResult {
        let dtos = sessions.map { TrainingSessionDTO(from: $0) }
        return try await api.request(Endpoint(.post, "/training-sessions/batch", body: dtos))
    }

    // MARK: - Angle Tests

    func uploadAngleTest(_ dto: AngleTestDTO) async throws {
        let _: AngleTestDTO = try await api.request(
            Endpoint(.post, "/angle-tests", body: dto)
        )
    }

    /// 与 `fetchSessionsAfter` 同形状：后端 `GET /angle-tests?after=` 路由已备好。
    func fetchAngleTestsAfter(_ date: Date?) async throws -> [SyncedRecord<AngleTestDTO>] {
        try await api.request(Endpoint(.get, "/angle-tests", query: Self.afterQuery(date)))
    }

    // MARK: - User

    func deleteAccount() async throws {
        let _: EmptyResponse = try await api.request(Endpoint(.delete, "/user/account"))
        KeychainService.clearAll()
    }
}
