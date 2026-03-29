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
}

struct AngleTestDTO: Codable {
    let clientId: String
    let date: Date
    let actualAngle: Double
    let userAngle: Double
    let pocketType: String

    init(from result: AngleTestResult) {
        self.clientId = result.id.uuidString
        self.date = result.date
        self.actualAngle = result.actualAngle
        self.userAngle = result.userAngle
        self.pocketType = result.pocketType
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
