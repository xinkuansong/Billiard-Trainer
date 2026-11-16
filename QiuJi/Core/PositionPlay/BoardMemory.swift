import SwiftUI
import Combine
import CryptoKit
import SceneKit

/// A page owns one local working board per account, independently of training results.
@MainActor
final class BoardMemory: ObservableObject {
    private struct Envelope: Codable {
        var version = 1
        let owner: String
        let page: String
        let payload: Data
    }
    private static var writers: [String: UUID] = [:]
    private let token = UUID()
    private let page: String
    private let root: URL
    private var owner = ""
    private var active = false
    private var unreadable = false
    private var previous: Data?
    private var observation: AnyCancellable?
    private var pending: Task<Void, Never>?
    private var capture: (() throws -> Data?)?
    private var restore: ((Data) throws -> Void)?
    @Published var message: String?

    init(page: String, root: URL? = nil) {
        self.page = page
        var directory = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("QiuJi/BoardMemory")
        #if DEBUG
        if root == nil, let domain = ProcessInfo.processInfo.environment["BOARD_MEMORY_TEST_DOMAIN"] {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("BoardMemory-" + domain)
        }
        #endif
        self.root = directory
    }
    private var key: String { root.path + "/" + owner + "/" + page }
    private var file: URL {
        let hash = SHA256.hash(data: Data(owner.utf8)).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent(hash).appendingPathComponent(page + ".json")
    }

    func begin<Value: Codable>(owner: String, changes: ObservableObjectPublisher,
                               imported: Bool = false, capture: @escaping () -> Value?,
                               restore: @escaping (Value) throws -> Void) {
        end()
        self.owner = owner
        Self.writers[key] = token
        self.capture = {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            return try capture().map { try encoder.encode($0) }
        }
        self.restore = { try restore(JSONDecoder().decode(Value.self, from: $0)) }
        unreadable = false
        previous = nil
        message = nil
        if !imported, FileManager.default.fileExists(atPath: file.path) {
            do {
                let envelope = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: file))
                guard envelope.version == 1, envelope.page == page, envelope.owner == owner else {
                    throw CocoaError(.coderReadCorrupt)
                }
                try self.restore?(envelope.payload)
                previous = envelope.payload
            } catch {
                unreadable = true
                message = "球形记忆无法恢复，原记录已保留。可选择恢复默认球形。"
            }
        }
        active = true
        observation = changes.sink { [weak self] in
            // Commit after the model has finished its synchronous multi-field change.
            self?.pending?.cancel()
            self?.pending = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                guard !Task.isCancelled else { return }
                self?.save()
            }
        }
        save()
    }

    func save() {
        guard active, !unreadable, Self.writers[key] == token else { return }
        do {
            guard let payload = try capture?(), payload != previous else { return }
            let value = Envelope(owner: owner, page: page, payload: payload)
            let data = try JSONEncoder().encode(value)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            previous = payload
            if message != nil { message = nil }
        } catch {
            if message == nil { message = "球形记忆保存失败，将在下次操作时重试。" }
        }
    }

    func reset(_ action: () -> Void) {
        pending?.cancel()
        active = false
        do {
            if unreadable, FileManager.default.fileExists(atPath: file.path) {
                try FileManager.default.copyItem(at: file, to: file.appendingPathExtension("preserved-" + UUID().uuidString))
            }
            action()
            unreadable = false
            previous = nil
            message = nil
        } catch { message = "原记录未能备份，请稍后重试恢复默认球形。" }
        active = true
        save()
    }

    func end() {
        save()
        active = false
        pending?.cancel()
        pending = nil
        observation = nil
    }
}

enum BoardMemoryValidation {
    static func check(_ board: BoardSnapshot) throws {
        guard board.onTable.keys.allSatisfy({ PositionPlayBall.allKeys.contains($0) }),
              board.onTable.values.allSatisfy({ $0.x.isFinite && $0.y.isFinite
                  && (0...1).contains($0.x) && (0...0.5).contains($0.y) }) else {
            throw CocoaError(.coderReadCorrupt)
        }
    }
}

struct BoardMemoryNotice: ViewModifier {
    @ObservedObject var memory: BoardMemory
    func body(content: Content) -> some View {
        content.btToast(Binding(get: { memory.message.map { BTToastMessage($0, tone: .error) } },
                                set: { memory.message = $0?.text }))
    }
}

/// Only free-board teaching pages opt in. Assessment and authored drill hosts keep their contracts.
@MainActor
protocol BoardMemoryHosting: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    associatedtype SavedBoard: Codable
    var boardMemory: BoardMemory { get }
    var savedBoard: SavedBoard? { get }
    func restoreSavedBoard(_ value: SavedBoard) throws
    func resetRememberedBoard()
}

extension BoardMemoryHosting {
    func beginBoardMemory(imported: Bool = false) {
        boardMemory.begin(owner: CurrentOwnerContext.shared.ownerKey, changes: objectWillChange,
            imported: imported, capture: { [weak self] in self?.savedBoard },
            restore: { [weak self] value in try self?.restoreSavedBoard(value) })
    }
}

struct OptionalBoardMemoryNotice: ViewModifier {
    let memory: BoardMemory?
    @ViewBuilder func body(content: Content) -> some View {
        if let memory { content.modifier(BoardMemoryNotice(memory: memory)) }
        else { content }
    }
}

struct SavedSolveInput: Codable {
    let catalog: PlannedShot
    let adjusted: PlannedShot
    func matches(_ shot: PlannedShot) -> Bool {
        shot.targetKey == catalog.targetKey && shot.pocket == catalog.pocket
            && abs(shot.velocity - catalog.velocity) < 0.0001
            && abs(shot.spinX - catalog.spinX) < 0.0001
            && abs(shot.spinY - catalog.spinY) < 0.0001
            && shot.freeAim?.x == catalog.freeAim?.x && shot.freeAim?.y == catalog.freeAim?.y
    }
}

extension BoardMemoryValidation {
    static func check(_ draft: SolveConstraintDraft?) throws {
        func point(_ p: CanvasPoint) -> Bool { p.x.isFinite && p.y.isFinite && abs(p.x) <= 2 && abs(p.y) <= 2 }
        let valid: Bool
        switch draft {
        case nil: valid = true
        case .restPoint(let p), .passPoint(let p): valid = point(p)
        case .region(let region):
            switch region {
            case .rect(let p, let w, let h): valid = point(p) && w.isFinite && h.isFinite && w > 0 && h > 0
            case .circle(let p, let r), .point(let p, let r): valid = point(p) && r.isFinite && r > 0
            case .sector(let p, let lo, let hi, let intervals):
                valid = point(p) && lo.isFinite && hi.isFinite && lo >= 0 && hi >= lo
                    && intervals.allSatisfy { $0.lo.isFinite && $0.hi.isFinite && $0.hi >= $0.lo }
            case .sampled(let value):
                valid = !value.polygons.isEmpty && value.polygons.allSatisfy { polygon in
                    polygon.count >= 3 && polygon.allSatisfy { $0.x.isFinite && $0.y.isFinite && abs($0.x) < 10 && abs($0.y) < 10 }
                } && value.boundaryLoops.allSatisfy { $0.allSatisfy { $0.x.isFinite && $0.y.isFinite } }
            }
        }
        guard valid else { throw CocoaError(.coderReadCorrupt) }
    }
    static func check(_ input: SavedSolveInput?) throws {
        guard let input else { return }
        for shot in [input.catalog, input.adjusted] {
            guard shot.velocity.isFinite, shot.spinX.isFinite, shot.spinY.isFinite,
                  shot.velocity > 0, abs(shot.spinX) <= 1, abs(shot.spinY) <= 1 else { throw CocoaError(.coderReadCorrupt) }
        }
    }
}

struct SavedBallRest: Codable {
    let position: [Float]
    let orientation: [Float]
    init(_ state: BallRestState) {
        position = [state.position.x, state.position.y, state.position.z]
        let q = state.orientation.vector
        orientation = [q.x, q.y, q.z, q.w]
    }
    func restored() throws -> BallRestState {
        guard position.count == 3, orientation.count == 4,
              position.allSatisfy(\.isFinite), orientation.allSatisfy(\.isFinite),
              position.allSatisfy({ abs($0) < 10 }) else { throw CocoaError(.coderReadCorrupt) }
        let q = SIMD4<Float>(orientation[0], orientation[1], orientation[2], orientation[3])
        guard abs(simd_length(q) - 1) < 0.01 else { throw CocoaError(.coderReadCorrupt) }
        return BallRestState(position: SCNVector3(position[0], position[1], position[2]), orientation: simd_quatf(vector: q))
    }
}

struct SavedCushionBoard: Codable {
    let target: String
    let poses: [String: SavedBallRest]
    let free: Bool
    let pocket: Int?
    let cushions: Int?
    let direction: [Float]?
    let power, spinX, spinY, catalogPower: Double
    let catalogDirection: [Float]?
    func validate() throws {
        guard PositionPlayBall.objectKeys.contains(target), pocket.map({ (0..<6).contains($0) }) ?? true,
              cushions.map({ (1...4).contains($0) }) ?? true,
              direction.map({ $0.count == 3 && $0.allSatisfy(\.isFinite) }) ?? true,
              catalogDirection.map({ $0.count == 3 && $0.allSatisfy(\.isFinite) }) ?? true,
              [power, spinX, spinY, catalogPower].allSatisfy(\.isFinite), power > 0, catalogPower > 0,
              abs(spinX) <= 1, abs(spinY) <= 1,
              poses.keys.allSatisfy({ ["__cue", "__target"].contains($0) || PositionPlayBall.objectKeys.contains($0) })
        else { throw CocoaError(.coderReadCorrupt) }
        for pose in poses.values { _ = try pose.restored() }
    }
    func matches(_ direction: SCNVector3?) -> Bool {
        guard let direction, let expected = catalogDirection else { return false }
        return abs(direction.x - expected[0]) < 0.0001 && abs(direction.y - expected[1]) < 0.0001 && abs(direction.z - expected[2]) < 0.0001
    }
}

struct SavedObservationBoard: Codable {
    let board: BoardSnapshot
    let target: String?
    let pockets: [String: Int]
    func validate() throws {
        try BoardMemoryValidation.check(board)
        guard target.map({ board.onTable[$0] != nil && !PositionPlayBall.isCue($0) }) ?? true,
              pockets.allSatisfy({ board.onTable[$0.key] != nil && !PositionPlayBall.isCue($0.key) && (-1..<6).contains($0.value) })
        else { throw CocoaError(.coderReadCorrupt) }
    }
    @MainActor static func capture(_ scene: AngleTrainingScene) -> BoardSnapshot {
        var points: [String: CanvasPoint] = [:]
        for (key, node) in scene.allBallNodes where !node.isHidden {
            let p = AngleSceneCalculator.sceneToNormalized(position: node.position)
            points[key] = .init(x: Double(p.x), y: Double(p.y))
        }
        return .init(onTable: points)
    }
    @MainActor func apply(to scene: AngleTrainingScene) {
        scene.hideAllBalls()
        for (key, p) in board.onTable {
            scene.showBall(key: key, scenePosition: AngleSceneCalculator.normalizedToScene(
                point: CGPoint(x: p.x, y: p.y), surfaceY: scene.surfaceY))
        }
    }
}
