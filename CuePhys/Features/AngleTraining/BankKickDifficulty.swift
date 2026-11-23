//
//  BankKickDifficulty.swift
//  QiuJi
//
//  翻袋/反射解球页「好打优先」排序（W3，docs/research/20260709-翻袋反射页重构方案 §3）。
//
//  Measured-route grouping and minimum-spin representatives precede cross-route ranking.
//  Difficulty uses shot geometry; robustness probes aim, speed and horizontal contact error.
//  Every reduced-spin candidate reuses the production aim search and physics verification.
//
//  坐标契约：SceneKit 世界系，水平面 X–Z、+Y 朝上；长库 = 常 Z（±halfW）、短库 = 常 X（±halfL）。
//

import Foundation
import SceneKit

// MARK: - 页面模式（W6：求解 / 自由，方案 §1.1 状态机）

/// 翻袋/反射解球页双模式：`solve` = 引擎反解 + 击打演示；`free` = 用户自定瞄准/打点/力度，
/// `simulateFree` 真物理试手（球停在哪是哪）。
enum BankKickPageMode {
    case solve
    case free
}

// MARK: - 自由模式首碰胶囊文案（两页共用）

enum BankKickFreePill {
    /// USDZ 球键 → 用户可读名（`_8` → 「8 号球」）。
    static func ballName(_ key: String) -> String {
        key.hasPrefix("_") ? "\(key.dropFirst()) 号球" : key
    }
}

// MARK: - Tier（易/中/难档位，pill 文案与 E2 标签对齐）

enum BankKickDifficultyTier: Int, Comparable, CaseIterable {
    case easy = 0
    case medium = 1
    case hard = 2

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .easy: "易"
        case .medium: "中"
        case .hard: "难"
        }
    }
}

/// Validation facts have no playable/final-table API. A settled probe is still not a playback result.
struct BankKickValidation {
    let feasible: Bool
    let termination: EventDrivenEngine.Termination?
    let cuePocketed: Bool
    let simObjectPotted: Bool
    let cueCushionsBeforeContact: Int
    let events: [ShotEvent]
    let objectStart: SCNVector3?
    let objectDepartureDir: SCNVector3?
    let objectRailContacts: [BankShotCalculator.Rail]
}

extension BankKickValidation {
    init(_ prediction: ShotPrediction) {
        self.init(feasible: prediction.feasible, termination: prediction.termination,
            cuePocketed: prediction.cuePocketed, simObjectPotted: prediction.simObjectPotted,
            cueCushionsBeforeContact: prediction.cueCushionsBeforeContact, events: prediction.events,
            objectStart: prediction.recorder?.framesByBallName[ShotInput.targetBallName]?.first?.position,
            objectDepartureDir: prediction.objectDepartureDir, objectRailContacts: prediction.objectRailContacts)
    }
}

/// Tool-page success contract. Prescribed practice rail orders stay in practice;
/// both entry points require a cue/target cushion strictly after first target contact.
enum BankKickValidity {
    static func hasPostContactRail(events: [ShotEvent], afterContactAt index: Int) -> Bool {
        guard events.indices.contains(index) else { return false }
        let contactTime = events[index].time
        return events.dropFirst(index + 1).contains { event in
            guard event.time > contactTime, case let .ballCushion(ball) = event.kind else { return false }
            return ball == ShotInput.cueBallName || ball == ShotInput.targetBallName
        }
    }
    /// A bank must not rely on the cue hitting the target again before capture.
    /// Inspect events rather than intersecting paths: crossings at different times are valid.
    static func hasRepeatedCueTargetContact(events: [ShotEvent]) -> Bool {
        var contacted = false
        for event in events {
            switch event.kind {
            case .pocket(let ball, _) where ball == ShotInput.targetBallName:
                return false
            case .ballBall(let a, let b)
                where (a == ShotInput.cueBallName && b == ShotInput.targetBallName)
                    || (b == ShotInput.cueBallName && a == ShotInput.targetBallName):
                if contacted { return true }
                contacted = true
            default: break
            }
        }
        return false
    }

    static func bank(_ p: ShotPrediction) -> Bool { bank(BankKickValidation(p)) }

    static func bank(_ p: BankKickValidation) -> Bool {
        guard p.feasible, p.termination == .settled, !p.cuePocketed, p.simObjectPotted,
              p.cueCushionsBeforeContact == 0,
              !hasRepeatedCueTargetContact(events: p.events),
              ShotPredictor.kickContactInfo(events: p.events).contacted else { return false }
        let object = p.objectStart
        let rails = object.map {
            BankShotCalculator.reconstructedRailContacts(object: $0,
                departure: p.objectDepartureDir, engineRails: p.objectRailContacts)
        } ?? p.objectRailContacts
        return !rails.isEmpty
    }

    static func kick(_ p: ShotPrediction) -> Bool { kick(BankKickValidation(p)) }

    static func kick(_ p: BankKickValidation) -> Bool {
        guard p.feasible, p.termination == .settled, !p.cuePocketed,
              ShotPredictor.kickContactInfo(events: p.events).contacted else { return false }
        var hasPreContactRail = false
        for (index, event) in p.events.enumerated() {
            if case .ballBall(let a, let b) = event.kind,
               a == ShotInput.cueBallName || b == ShotInput.cueBallName {
                return hasPreContactRail && hasPostContactRail(events: p.events, afterContactAt: index)
            }
            if case .ballCushion(let ball) = event.kind, ball == ShotInput.cueBallName,
               let index = event.cushionIndex, let normal = event.contactNormal,
               ShotPredictor.mainRail(cushionIndex: index, normal: normal) != nil { hasPreContactRail = true }
        }
        return false
    }
}

/// Recommendation policy, independent of shot legality and practice question contracts.
enum BankKickRouteQuality {
    static func hasConsecutiveParallelRails(_ rails: [BankShotCalculator.Rail]) -> Bool {
        zip(rails, rails.dropFirst()).contains { first, second in
            first != second && first.isLong == second.isLong
        }
    }
}

enum BankRouteQuality {
    /// Only target main cushions between the first cue/target collision and capture.
    /// Pocket jaws do not introduce a new main wall; cue/obstacle routes are irrelevant.
    static func hasConsecutiveParallelRails(events: [ShotEvent]) -> Bool {
        var contacted = false
        var rails: [BankShotCalculator.Rail] = []
        for event in events {
            switch event.kind {
            case let .ballBall(a, b) where
                (a == ShotInput.cueBallName && b == ShotInput.targetBallName)
                || (b == ShotInput.cueBallName && a == ShotInput.targetBallName):
                contacted = true
            case .pocket(let ball, _) where ball == ShotInput.targetBallName:
                return BankKickRouteQuality.hasConsecutiveParallelRails(rails)
            case .ballCushion(let ball) where contacted && ball == ShotInput.targetBallName:
                if let index = event.cushionIndex, let normal = event.contactNormal,
                   let rail = ShotPredictor.mainRail(cushionIndex: index, normal: normal),
                   rails.last != rail { rails.append(rail) }
            default: break
            }
        }
        return BankKickRouteQuality.hasConsecutiveParallelRails(rails)
    }

    static func accepts(_ prediction: ShotPrediction) -> Bool { accepts(BankKickValidation(prediction)) }
    static func accepts(_ facts: BankKickValidation) -> Bool {
        BankKickValidity.bank(facts) && !hasConsecutiveParallelRails(events: facts.events)
    }
}

/// Recommendation quality is separate from physical feasibility and practice judgement.
/// Inspect only the cue's route before its first ball contact. Post-contact jaws and
/// opposite parallel walls are excluded even for two contacts; perpendicular turns remain.
enum KickRouteQuality {
    enum Rejection: String { case pocketCushion, consecutiveParallelRails }

    /// Treat residual offsets within 1% of a ball diameter (0.5715 mm) as centered.
    /// This avoids spending sidespin on insignificant differences in search precision.
    static let centeredContactTolerance: Float = 0.01

    /// Normalized transverse impact parameter: 0 = full ball, 1 = grazing.
    /// Use the incoming state, never the deflected post-collision velocity.
    static func contactOffset(incoming: BallState, target: SCNVector3) -> Float {
        let dx = target.x - incoming.position.x, dz = target.z - incoming.position.z
        let vx = incoming.velocity.x, vz = incoming.velocity.z
        let scale = hypotf(dx, dz) * hypotf(vx, vz)
        guard scale > 0 else { return 1 }
        return min(1, abs(dx * vz - dz * vx) / scale)
    }

    static func contactOffset(_ prediction: ShotPrediction) -> Float {
        guard let contact = prediction.recorder?.firstBallContacts[ShotInput.cueBallName],
              contact.other.name == ShotInput.targetBallName else { return 1 }
        return contactOffset(incoming: contact.incoming, target: contact.other.position)
    }

    static func rejection(events: [ShotEvent]) -> Rejection? {
        var rails: [BankShotCalculator.Rail] = []
        for event in events {
            if case let .ballBall(a, b) = event.kind,
               a == ShotInput.cueBallName || b == ShotInput.cueBallName { break }
            guard case let .ballCushion(ball) = event.kind, ball == ShotInput.cueBallName else { continue }
            guard let index = event.cushionIndex, let normal = event.contactNormal,
                  let rail = ShotPredictor.mainRail(cushionIndex: index, normal: normal) else {
                return .pocketCushion
            }
            if rails.last != rail { rails.append(rail) }
        }
        return BankKickRouteQuality.hasConsecutiveParallelRails(rails) ? .consecutiveParallelRails : nil
    }

    static func accepts(_ prediction: ShotPrediction) -> Bool {
        accepts(BankKickValidation(prediction))
    }
    static func accepts(_ facts: BankKickValidation) -> Bool {
        BankKickValidity.kick(facts) && rejection(events: facts.events) == nil
    }
}

// MARK: - Model（常量集中可调，方案 §3「E1 模式：单一真源」）

enum BankKickDifficulty {

    // MARK: 常量

    /// 切角难度起算点/跨度/权重（E4 同参：60° 起算、~90° 满档、75° 薄球）。
    static let cutAngleOnsetDeg = 60.0
    static let cutAngleSpanDeg = 30.0
    static let cutAngleWeight = 0.8
    /// 球距难度起算点（米）与斜率（E4 同参）。
    static let distanceOnsetMeters = 1.0
    static let distanceSlope = 0.3
    /// 每多一库的难度增量（速度衰减 + 库边不确定性叠加）。
    static let perCushionWeight = 0.22
    /// 解线路径长难度：起算点（米）与斜率（长路径放大执行误差）。
    static let pathLengthOnsetMeters = 1.0
    static let pathLengthSlope = 0.12
    /// 反射页首库入射角余量（无切角语义的替代输入，方案 §3）：入射角（相对库面）
    /// 越平越难。低于满余量角起算，线性升至下限角满档。
    static let firstRailFullMarginDeg = 60.0
    static let firstRailMinAngleDeg = 15.0
    static let firstRailMarginWeight = 0.5
    /// 好打分合成：`好打分 = 难度评分 − robustnessWeight·robustness`（升序 = 越好打越靠前）。
    /// 翻袋是「悬崖解」重灾区，容错是主要区分量。
    static let robustnessWeight = 0.8
    /// 档位阈值（难度评分，不含容错）。
    static let tierBoundaries = (easy: 0.55, medium: 1.1)

    /// Aim / speed probes plus horizontal contact-point error, including zero-spin shots.
    static let probeAimDeltaDeg = 0.5
    static let probeVelocityFactor = 0.08
    static let probeSpinDelta: Float = 0.02

    // MARK: 难度评分

    /// 翻袋解难度：切角（引擎碰撞口径）+ 球距 + 库数 + 路径长。无量纲，越大越难。
    static func bankScore(
        cutAngleDeg: Double?, cueTargetDistance: Double, cushions: Int, pathLength: Double
    ) -> Double {
        var s = 0.0
        if let cut = cutAngleDeg {
            s += max(0, cut - cutAngleOnsetDeg) / cutAngleSpanDeg * cutAngleWeight
        }
        s += max(0, cueTargetDistance - distanceOnsetMeters) * distanceSlope
        s += Double(cushions) * perCushionWeight
        s += max(0, pathLength - pathLengthOnsetMeters) * pathLengthSlope
        return s
    }

    /// 反射（kick）解难度：首库入射角余量（切角替代输入）+ 库数 + 路径长。
    static func kickScore(
        firstRailIncidenceDeg: Double?, cushions: Int, pathLength: Double
    ) -> Double {
        var s = 0.0
        if let angle = firstRailIncidenceDeg {
            let span = firstRailFullMarginDeg - firstRailMinAngleDeg
            let deficit = (firstRailFullMarginDeg - angle) / span
            s += min(1, max(0, deficit)) * firstRailMarginWeight
        }
        s += Double(cushions) * perCushionWeight
        s += max(0, pathLength - pathLengthOnsetMeters) * pathLengthSlope
        return s
    }

    static func tier(_ score: Double) -> BankKickDifficultyTier {
        if score < tierBoundaries.easy { return .easy }
        if score < tierBoundaries.medium { return .medium }
        return .hard
    }

    /// 排序键：越小越「好打」。robustness nil（未测出）按 0 保守处理。
    static func goodness(difficultyScore: Double, robustness: Double?) -> Double {
        difficultyScore - robustnessWeight * (robustness ?? 0)
    }

    // MARK: 完整轨迹扰动容错（瞄准 ±0.5° / 力度 ±8% / 横向打点 ±0.02R）

    /// Six deterministic probes; this fraction is not a calibrated success probability.
    /// 固定参考方向独立正向模拟；扰动后不重新寻优。
    static func measureBankRobustness(
        input baseInput: ShotInput, rails: [BankShotCalculator.Rail], aimOffset: Float,
        cancellation: PredictionCancellation? = nil
    ) -> Double? {
        var input = baseInput
        input.bankRails = rails
        var scratch = ShotPrediction()
        guard let ctx = ShotPredictor.prepareAim(input, into: &scratch) else { return nil }
        let aimDelta = Float(probeAimDeltaDeg) * .pi / 180
        let vFactor = Float(probeVelocityFactor)
        var succeeded = 0
        for probe in perturbations(offset: aimOffset, velocity: input.velocity,
                                   aimDelta: aimDelta, vFactor: vFactor) {
            var pInput = input
            pInput.velocity = probe.velocity
            guard cancellation?.isCancelled != true else { return nil }
            if BankRouteQuality.accepts(ShotPredictor.bankKickValidation(input: pInput, context: ctx,
                offset: probe.offset, cancellation: cancellation)) {
                succeeded += 1
            }
        }
        for delta in [-probeSpinDelta, probeSpinDelta] {
            var probe = input
            probe.spinX += delta
            guard cancellation?.isCancelled != true else { return nil }
            if BankRouteQuality.accepts(ShotPredictor.bankKickValidation(input: probe, context: ctx,
                offset: aimOffset, cancellation: cancellation)) {
                succeeded += 1
            }
        }
        return Double(succeeded) / 6.0
    }

    /// Six probes of aim, speed and horizontal contact-point error.
    static func measureKickRobustness(
        input baseInput: ShotInput, rails: [DiamondSystemCalculator.Rail], aimOffset: Float,
        cancellation: PredictionCancellation? = nil
    ) -> Double? {
        var input = baseInput
        input.kickRails = rails
        var scratch = ShotPrediction()
        guard let ctx = ShotPredictor.prepareAim(input, into: &scratch) else { return nil }
        let aimDelta = Float(probeAimDeltaDeg) * .pi / 180
        let vFactor = Float(probeVelocityFactor)
        var succeeded = 0
        for probe in perturbations(offset: aimOffset, velocity: input.velocity,
                                   aimDelta: aimDelta, vFactor: vFactor) {
            var pInput = input
            pInput.velocity = probe.velocity
            guard cancellation?.isCancelled != true else { return nil }
            if KickRouteQuality.accepts(ShotPredictor.bankKickValidation(input: pInput, context: ctx,
                offset: probe.offset, cancellation: cancellation)) {
                succeeded += 1
            }
        }
        for delta in [-probeSpinDelta, probeSpinDelta] {
            var probe = input
            probe.spinX += delta
            guard cancellation?.isCancelled != true else { return nil }
            if KickRouteQuality.accepts(ShotPredictor.bankKickValidation(input: probe, context: ctx,
                offset: aimOffset, cancellation: cancellation)) {
                succeeded += 1
            }
        }
        return Double(succeeded) / 6.0
    }

    private static func perturbations(
        offset: Float, velocity: Float, aimDelta: Float, vFactor: Float
    ) -> [(offset: Float, velocity: Float)] {
        [
            (offset + aimDelta, velocity),
            (offset - aimDelta, velocity),
            (offset, velocity * (1 + vFactor)),
            (offset, velocity * (1 - vFactor))
        ]
    }
}

// MARK: - 解模型（基于引擎全保真 ShotPrediction 装配，方案 §3）

/// 翻袋页解（引擎全保真物化）。`rails`/`cushions` = **实测主库序**（引擎事件流主库
/// 分类 + 贴库首弹重建，`BankShotCalculator.reconstructedRailContacts`）——画面、文案、
/// 库数 chip 同一真源；种子库序只作搜索锚不上屏。jaw 擦碰不计（`objectCushionCount`
/// 含 jaw、仅供诊断）。
/// K10：`spinX`/`spinY` = 该解搜索/击打用的加塞（接触点偏移/R；+X 左塞 / −X 右塞）。
/// `usedFrozenRailSeed` = 首库为目标球所贴自库（扎库解，文案「扎库(自库)」）。
struct BankEngineSolution: Identifiable {
    let id = UUID()
    let rails: [BankShotCalculator.Rail]
    /// 种子库序（搜索锚）：微调重算（K11 `adjustCurrentSolution`）沿原库序 predict 用；
    /// 与展示 `rails`（实测）可能不同——扎库解种子不含自库。
    let seedRails: [BankShotCalculator.Rail]
    let prediction: ShotPrediction
    let cushions: Int
    let difficultyScore: Double
    let difficultyTier: BankKickDifficultyTier
    let robustness: Double?
    let pathLength: Double
    let spinX: Float
    let spinY: Float
    let usedFrozenRailSeed: Bool
    var measuredRoute: BankKickRoute? = nil

    var goodness: Double {
        BankKickDifficulty.goodness(difficultyScore: difficultyScore, robustness: robustness)
    }
    var railSequenceText: String {
        guard usedFrozenRailSeed, let first = rails.first else {
            return rails.map(\.label).joined(separator: " → ")
        }
        let rest = rails.dropFirst().map(\.label).joined(separator: " → ")
        return rest.isEmpty ? "扎库(\(first.label))" : "扎库(\(first.label)) → \(rest)"
    }
    var spinLabel: String {
        ShotSpinLabel.text(spinX: Double(spinX), spinY: Double(spinY))
    }
}

/// Kick display rails/count come from main-rail events before the cue's first ball contact.
/// K10：同翻袋，解携带搜索时的加塞。
struct KickEngineSolution: Identifiable {
    let id = UUID()
    let rails: [DiamondSystemCalculator.Rail]
    let seedRails: [DiamondSystemCalculator.Rail]
    let prediction: ShotPrediction
    let cushions: Int
    let difficultyScore: Double
    let difficultyTier: BankKickDifficultyTier
    let robustness: Double?
    let pathLength: Double
    let spinX: Float
    let spinY: Float
    var measuredRoute: BankKickRoute? = nil

    var goodness: Double {
        BankKickDifficulty.goodness(difficultyScore: difficultyScore, robustness: robustness)
    }
    var railSequenceText: String { rails.map(\.label).joined(separator: " → ") }
    var spinLabel: String {
        ShotSpinLabel.text(spinX: Double(spinX), spinY: Double(spinY))
    }
}

/// Banks: one selected pocket + one measured main-rail sequence = one solution.
/// Jaw motion and different contact points are variants, not additional routes.
/// Kicks: one target in the solve request + one measured pre-contact rail sequence.
/// Full/thin contacts, spin and bounce positions are variants of that route.
struct BankKickRoute {
    let rails: [BankShotCalculator.Rail]
    let contacts: [SCNVector3]
    let path: [SCNVector3]
    let pocketID: String?
    func matches(_ other: Self) -> Bool {
        pocketID == other.pocketID && rails == other.rails
    }

    static func measured(_ prediction: ShotPrediction, kick: Bool) -> Self? {
        let ball = kick ? ShotInput.cueBallName : ShotInput.targetBallName
        guard let recorder = prediction.recorder,
              let frames = recorder.framesByBallName[ball], !frames.isEmpty else { return nil }
        var rails: [BankShotCalculator.Rail] = []
        var contacts: [SCNVector3] = []
        var endTime: Float?
        var pocketID: String?
        for event in prediction.events {
            switch event.kind {
            case let .ballBall(a, b) where kick && (a == ball || b == ball):
                endTime = event.time
            case let .pocket(name, id) where name == ball:
                endTime = event.time
                pocketID = id
            case let .ballCushion(name) where name == ball:
                if let index = event.cushionIndex, let normal = event.contactNormal,
                   let rail = ShotPredictor.mainRail(cushionIndex: index, normal: normal),
                   rails.last != rail,
                   let point = recorder.stateAt(ballName: ball, time: event.time)?.position {
                    rails.append(rail)
                    contacts.append(point)
                }
            default: break
            }
            if endTime != nil { break }
        }
        // A manual adjustment can miss; its displayed rail sequence still comes from events.
        if kick && endTime == nil { endTime = frames.last?.time }
        guard let endTime else { return nil }
        var path = frames.filter { $0.time < endTime }.map(\.position)
        if let end = recorder.stateAt(ballName: ball, time: endTime)?.position { path.append(end) }
        guard path.count >= 2 else { return nil }
        if !kick {
            let reconstructed = BankShotCalculator.reconstructedRailContacts(
                object: path[0], departure: prediction.objectDepartureDir, engineRails: rails)
            if reconstructed.count > rails.count { contacts.insert(path[0], at: 0) }
            rails = reconstructed
        }
        return Self(rails: rails, contacts: contacts, path: path, pocketID: pocketID)
    }

    var kickRails: [DiamondSystemCalculator.Rail] {
        rails.map {
            switch $0 {
            case .left: .left
            case .right: .right
            case .far: .far
            case .near: .near
            }
        }
    }

    var firstRailIncidence: Double? {
        guard let rail = rails.first, let contact = contacts.first, let start = path.first else { return nil }
        let dx = abs(contact.x - start.x), dz = abs(contact.z - start.z)
        guard dx + dz > 0 else { return nil }
        return Double(rail.isLong ? atan2f(dz, dx) : atan2f(dx, dz)) * 180 / .pi
    }
}

// MARK: - 求解管线（VM 与测试共用的纯函数入口）

enum BankKickSolvePipeline {

    /// 翻袋解上限（沿用旧页上限，方案 §2.1）。
    static let bankSolutionLimit = 12
    /// 反射解上限。
    static let kickSolutionLimit = 16
    /// K10 加塞搜索档（与走位反解 `spinXValues` 同口径）：≈×3 全枚举成本。
    /// 坐标契约：spinX = 接触点偏移/R，+左塞 / −右塞；本档只搜横塞，spinY 恒 0。
    static let sideSpinSearchValues: [Float] = [0, -0.3, 0.3]
    /// Minimum spin is searched on this finite grid, re-solving aim at every step.
    /// No monotonic-feasibility assumption / binary search across disconnected success windows.
    static let minimumSpinStep: Float = 0.02

    /// 翻袋单袋全枚举 → 装配难度/容错 → 好打优先排序（升序）→ 去重取前 N。
    /// 纯函数、线程安全，供 VM 后台任务与测试直接调用。
    /// `obstacles` = 球库拖入的在桌障碍球（W4，方案 §4.3）：**真实碰撞体**进反解模拟
    /// 与容错扰动（目标球/母球撞障碍 = 候选被引擎自然淘汰，非几何过滤）。
    /// K10：外层枚举 `sideSpinSearchValues`；引擎管线（squirt）已支持，本函数只消费。
    static func solveBank(
        cue: SCNVector3, object: SCNVector3, pocketIndex: Int,
        surfaceY: Float, power: Float, obstacles: [ObstacleBall] = [],
        spinXValues: [Float] = sideSpinSearchValues,
        cancellation: PredictionCancellation? = nil, limit: Int? = bankSolutionLimit,
        parallelRefinement: Bool = true
    ) -> [BankEngineSolution] {
        var input = ShotInput(cueBall: cue, targetBall: object, pocketIndex: pocketIndex,
                              velocity: power, spinX: 0, spinY: 0, surfaceY: surfaceY)
        input.obstacles = obstacles
        var phaseStart = MixedLoopPhaseClock.now()
        var solutions: [BankEngineSolution] = []
        for sx in spinXValues {
            guard cancellation?.isCancelled != true else { return [] }
            input.spinX = sx
            for (seedRails, pred) in ShotPredictor.predictBankAll(input, cancellation: cancellation, includePresentation: false) {
                if let solution = bankSolution(input: input, seedRails: seedRails, prediction: pred, measureRobustness: false) {
                    solutions.append(solution)
                }
            }
        }
        PerformanceProfiler.recordSample("BankKick.wall.initialSearch", ms: (MixedLoopPhaseClock.now() - phaseStart) * 1000)
        phaseStart = MixedLoopPhaseClock.now()
        let baseInput = input
        let attempted = Set(spinXValues.flatMap { spin in
            BankShotCalculator.candidateRailSequences(maxCushions: 3).map { SpinTrialKey(rails: $0, spin: spin) }
        })
        let reduced = minimumSpinRepresentatives(solutions, spinXValues: spinXValues,
                                                cancellation: cancellation, previouslyAttempted: attempted,
                                                parallelTrials: parallelRefinement) { candidate, sx in
            var trial = baseInput
            trial.spinX = sx
            trial.bankRails = candidate.seedRails
            let pred = ShotPredictor.predict(trial, bankCancellation: cancellation, includeBankKickPresentation: false)
            return bankSolution(input: trial, seedRails: candidate.seedRails, prediction: pred, measureRobustness: false)
        }
        guard cancellation?.isCancelled != true else { return [] }
        PerformanceProfiler.recordSample("BankKick.wall.reduceSpin", ms: (MixedLoopPhaseClock.now() - phaseStart) * 1000)
        phaseStart = MixedLoopPhaseClock.now()
        let scored = evaluateInOrder(reduced, parallel: parallelRefinement, cancellation: cancellation) { candidate -> BankEngineSolution? in
            guard cancellation?.isCancelled != true else { return nil }
            var trial = baseInput; trial.spinX = candidate.spinX; trial.bankRails = candidate.seedRails
            return bankSolution(input: trial, seedRails: candidate.seedRails,
                                prediction: ShotPredictor.materializeBankKick(candidate.prediction, input: trial),
                                cancellation: cancellation)
        }.compactMap { $0 }
        PerformanceProfiler.recordSample("BankKick.wall.scoreAndPresentation", ms: (MixedLoopPhaseClock.now() - phaseStart) * 1000)
        return cancellation?.isCancelled == true ? [] : rank(scored, limit: limit ?? Int.max)
    }

    static func bankSolution(input: ShotInput, seedRails: [BankShotCalculator.Rail],
                             prediction pred: ShotPrediction, measureRobustness: Bool = true,
                             cancellation: PredictionCancellation? = nil) -> BankEngineSolution? {
        guard BankRouteQuality.accepts(pred),
              let route = BankKickRoute.measured(pred, kick: false), !route.rails.isEmpty else { return nil }
        let length = Double(polylineLengthXZ(route.path))
        let distance = Double(hypotf(input.cueBall.x - input.targetBall.x,
                                    input.cueBall.z - input.targetBall.z))
        let score = BankKickDifficulty.bankScore(cutAngleDeg: pred.cutAngleDeg,
            cueTargetDistance: distance, cushions: route.rails.count, pathLength: length)
        let robustness = measureRobustness ? pred.aimOffsetUsed.flatMap {
            BankKickDifficulty.measureBankRobustness(input: input, rails: seedRails, aimOffset: $0, cancellation: cancellation)
        } : nil
        return BankEngineSolution(rails: route.rails, seedRails: seedRails, prediction: pred,
            cushions: route.rails.count, difficultyScore: score, difficultyTier: BankKickDifficulty.tier(score),
            robustness: robustness, pathLength: length, spinX: input.spinX, spinY: input.spinY,
            usedFrozenRailSeed: BankShotCalculator.frozenRails(for: input.targetBall).contains(route.rails[0]), measuredRoute: route)
    }

    /// Search seeds are retained only for re-solving; all display metadata uses measured routes.
    static func solveKick(
        cue: SCNVector3, target: SCNVector3, surfaceY: Float, power: Float,
        obstacles: [ObstacleBall] = [],
        spinXValues: [Float] = sideSpinSearchValues,
        cancellation: PredictionCancellation? = nil, limit: Int? = kickSolutionLimit,
        parallelRefinement: Bool = true
    ) -> [KickEngineSolution] {
        var input = ShotInput(cueBall: cue, targetBall: target, pocketIndex: 0,
                              velocity: power, spinX: 0, spinY: 0, surfaceY: surfaceY)
        input.obstacles = obstacles
        var phaseStart = MixedLoopPhaseClock.now()
        var solutions: [KickEngineSolution] = []
        for sx in spinXValues {
            guard cancellation?.isCancelled != true else { return [] }
            input.spinX = sx
            for (seedRails, pred) in ShotPredictor.predictKickAll(input, cancellation: cancellation, includePresentation: false) {
                if let solution = kickSolution(input: input, seedRails: seedRails, prediction: pred, measureRobustness: false) {
                    solutions.append(solution)
                }
            }
        }
        PerformanceProfiler.recordSample("BankKick.wall.initialSearch", ms: (MixedLoopPhaseClock.now() - phaseStart) * 1000)
        phaseStart = MixedLoopPhaseClock.now()
        let baseInput = input
        let attempted = Set(spinXValues.flatMap { spin in
            DiamondSystemCalculator.candidateRailSequences(maxCushions: 3).map { rails in
                SpinTrialKey(rails: rails.map { rail in
                    switch rail {
                    case .left: .left
                    case .right: .right
                    case .near: .near
                    case .far: .far
                    }
                }, spin: spin)
            }
        })
        let reduced = minimumSpinRepresentatives(solutions, spinXValues: spinXValues,
                                                cancellation: cancellation, previouslyAttempted: attempted,
                                                parallelTrials: parallelRefinement) { candidate, sx in
            var trial = baseInput
            trial.spinX = sx
            trial.kickRails = candidate.seedRails
            return kickSolution(input: trial, seedRails: candidate.seedRails,
                                prediction: ShotPredictor.predict(trial, bankCancellation: cancellation, includeBankKickPresentation: false), measureRobustness: false)
        }
        guard cancellation?.isCancelled != true else { return [] }
        PerformanceProfiler.recordSample("BankKick.wall.reduceSpin", ms: (MixedLoopPhaseClock.now() - phaseStart) * 1000)
        phaseStart = MixedLoopPhaseClock.now()
        let scored = evaluateInOrder(reduced, parallel: parallelRefinement, cancellation: cancellation) { candidate -> KickEngineSolution? in
            guard cancellation?.isCancelled != true else { return nil }
            var trial = baseInput; trial.spinX = candidate.spinX; trial.kickRails = candidate.seedRails
            return kickSolution(input: trial, seedRails: candidate.seedRails,
                                prediction: ShotPredictor.materializeBankKick(candidate.prediction, input: trial),
                                cancellation: cancellation)
        }.compactMap { $0 }
        PerformanceProfiler.recordSample("BankKick.wall.scoreAndPresentation", ms: (MixedLoopPhaseClock.now() - phaseStart) * 1000)
        return cancellation?.isCancelled == true ? [] : rank(scored, limit: limit ?? Int.max)
    }

    static func kickSolution(input: ShotInput, seedRails: [DiamondSystemCalculator.Rail],
                             prediction pred: ShotPrediction, measureRobustness: Bool = true,
                             cancellation: PredictionCancellation? = nil) -> KickEngineSolution? {
        guard KickRouteQuality.accepts(pred),
              let route = BankKickRoute.measured(pred, kick: true), !route.rails.isEmpty else { return nil }
        let length = Double(polylineLengthXZ(route.path))
        let score = BankKickDifficulty.kickScore(firstRailIncidenceDeg: route.firstRailIncidence,
            cushions: route.rails.count, pathLength: length)
        let robustness = measureRobustness ? pred.aimOffsetUsed.flatMap {
            BankKickDifficulty.measureKickRobustness(input: input, rails: seedRails, aimOffset: $0, cancellation: cancellation)
        } : nil
        return KickEngineSolution(rails: route.kickRails, seedRails: seedRails, prediction: pred,
            cushions: route.rails.count, difficultyScore: score, difficultyTier: BankKickDifficulty.tier(score),
            robustness: robustness, pathLength: length, spinX: input.spinX, spinY: input.spinY, measuredRoute: route)
    }

    /// Drafts remain playable even when unsuccessful; metadata never comes from the old catalog.
    static func bankDraft(input: ShotInput, seedRails: [BankShotCalculator.Rail],
                          prediction: ShotPrediction) -> BankEngineSolution {
        if let valid = bankSolution(input: input, seedRails: seedRails, prediction: prediction) { return valid }
        let route = BankKickRoute.measured(prediction, kick: false)
        let rails = route?.rails ?? prediction.objectRailContacts
        let length = Double(polylineLengthXZ(route?.path ?? prediction.objectPath))
        let score = BankKickDifficulty.bankScore(cutAngleDeg: prediction.cutAngleDeg,
            cueTargetDistance: Double(hypotf(input.cueBall.x - input.targetBall.x, input.cueBall.z - input.targetBall.z)),
            cushions: rails.count, pathLength: length)
        return BankEngineSolution(rails: rails, seedRails: seedRails, prediction: prediction,
            cushions: rails.count, difficultyScore: score, difficultyTier: BankKickDifficulty.tier(score),
            robustness: nil, pathLength: length, spinX: input.spinX, spinY: input.spinY,
            usedFrozenRailSeed: rails.first.map(BankShotCalculator.frozenRails(for: input.targetBall).contains) ?? false,
            measuredRoute: route)
    }

    static func kickDraft(input: ShotInput, seedRails: [DiamondSystemCalculator.Rail],
                          prediction: ShotPrediction) -> KickEngineSolution {
        if let valid = kickSolution(input: input, seedRails: seedRails, prediction: prediction) { return valid }
        let route = BankKickRoute.measured(prediction, kick: true)
        let length = Double(polylineLengthXZ(route?.path ?? pathToFirstContact(prediction)))
        let score = BankKickDifficulty.kickScore(firstRailIncidenceDeg: route?.firstRailIncidence,
            cushions: route?.rails.count ?? 0, pathLength: length)
        return KickEngineSolution(rails: route?.kickRails ?? [], seedRails: seedRails, prediction: prediction,
            cushions: route?.rails.count ?? 0, difficultyScore: score, difficultyTier: BankKickDifficulty.tier(score),
            robustness: nil, pathLength: length, spinX: input.spinX, spinY: input.spinY, measuredRoute: route)
    }

    // MARK: Route grouping / minimum-spin representatives / ranking

    private struct RouteGroup<S: RankableSolution> {
        let route: BankKickRoute
        var members: [S]
    }

    private static func preferred<S: RankableSolution>(_ a: S, _ b: S) -> Bool {
        if a.pocketContacts != b.pocketContacts { return a.pocketContacts < b.pocketContacts }
        if a.contactError != b.contactError { return a.contactError < b.contactError }
        if abs(a.spinX) != abs(b.spinX) { return abs(a.spinX) < abs(b.spinX) }
        if a.goodness != b.goodness { return a.goodness < b.goodness }
        return a.pathLength < b.pathLength
    }

    private static func groups<S: RankableSolution>(_ solutions: [S]) -> [RouteGroup<S>] {
        var groups: [RouteGroup<S>] = []
        // Anchor to the simplest candidate, rather than transitively chaining nearby routes.
        for solution in solutions.sorted(by: preferred) {
            guard let route = solution.route else { continue }
            if let index = groups.firstIndex(where: { $0.route.matches(route) }) {
                groups[index].members.append(solution)
            } else {
                groups.append(RouteGroup(route: route, members: [solution]))
            }
        }
        return groups
    }

    /// Request-local single-flight cache. Failed trials are cached too; concurrent route
    /// groups requesting one seed/spin share its completed result, never a partial value.
    private final class SpinTrialMemo<S> {
        private enum Entry { case running, completed(S?) }
        private var entries: [SpinTrialKey: Entry]
        private let condition = NSCondition()

        init(attempted: Set<SpinTrialKey>, successes: [SpinTrialKey: S]) {
            entries = Dictionary(uniqueKeysWithValues: attempted.map { ($0, .completed(nil)) })
            for (key, value) in successes { entries[key] = .completed(value) }
        }

        func value(for key: SpinTrialKey, resolve: () -> S?) -> S? {
            condition.lock()
            while true {
                switch entries[key] {
                case .completed(let result): condition.unlock(); return result
                case .running: condition.wait()
                case nil:
                    entries[key] = .running
                    condition.unlock()
                    let result = resolve()
                    condition.lock()
                    entries[key] = .completed(result)
                    condition.broadcast()
                    condition.unlock()
                    return result
                }
            }
        }
    }

    static func minimumSpinRepresentatives<S: RankableSolution>(
        _ solutions: [S], spinXValues: [Float], cancellation: PredictionCancellation? = nil,
        previouslyAttempted: Set<SpinTrialKey> = [], parallelTrials: Bool = false,
        resolve: (S, Float) -> S?
    ) -> [S] {
        let signs: [Float] = [-1, 1].filter { sign in spinXValues.contains { $0 * sign > 0 } }
        var successesByKey: [SpinTrialKey: S] = [:]
        for candidate in solutions {
            successesByKey[SpinTrialKey(rails: candidate.searchKey, spin: candidate.spinX)] = candidate
        }
        let memo = SpinTrialMemo(attempted: previouslyAttempted, successes: successesByKey)
        let routeGroups = groups(solutions)
        // Spend the bounded worker budget across independent routes, avoiding the per-spin
        // barrier that often left only two workers active. Small catalogs keep trial parallelism
        // so a single expensive route does not lose its two-sign concurrency.
        let refinableGroups = routeGroups.filter { $0.members[0].spinX != 0 }.count
        let parallelGroups = parallelTrials && refinableGroups >= 4
        let out = evaluateInOrder(routeGroups, parallel: parallelGroups, cancellation: cancellation) { group -> S? in
            guard cancellation?.isCancelled != true else { return nil }
            var best = group.members[0]
            if best.spinX == 0 { return best }
            var seeds: [S] = []
            for member in group.members where !seeds.contains(where: { $0.searchKey == member.searchKey }) {
                seeds.append(member)
            }
            // Each route retains its original sequential magnitude search, both signs,
            // disconnected windows and repeated minimization after its measured route moves.
            while best.spinX != 0, let reference = best.route {
                var chosen: S?
                let steps = Int((abs(best.spinX) / minimumSpinStep).nextDown.rounded(.up))
                for step in 0..<max(0, steps) {
                    let magnitude = Float(step) * minimumSpinStep
                    let spins: [Float] = step == 0 ? [0] : signs.map { $0 * magnitude }
                    let jobs = spins.flatMap { sx in seeds.map { (seed: $0, spin: sx) } }
                    let evaluated = evaluateInOrder(jobs, parallel: parallelTrials && !parallelGroups,
                                                    cancellation: cancellation) { job -> S? in
                        let key = SpinTrialKey(rails: job.seed.searchKey, spin: job.spin)
                        return memo.value(for: key) {
                            guard cancellation?.isCancelled != true else { return nil }
                            return resolve(job.seed, job.spin)
                        }
                    }
                    guard cancellation?.isCancelled != true else { return nil }
                    let successes = evaluated.compactMap { $0 }.filter { candidate in
                        candidate.pocketContacts <= best.pocketContacts &&
                            candidate.contactError <= best.contactError &&
                            (candidate.route.map { reference.matches($0) } ?? false)
                    }
                    if let winner = successes.sorted(by: preferred).first { chosen = winner; break }
                }
                guard let chosen, abs(chosen.spinX) < abs(best.spinX) else { break }
                best = chosen
            }
            return best
        }.compactMap { $0 }
        return cancellation?.isCancelled == true ? [] : out
    }

    /// Independent simulations own their engine/recorder. Only result slots are written
    /// concurrently; cache mutation, route selection and ranking stay in deterministic order.
    private static func evaluateInOrder<Input, Output>(
        _ inputs: [Input], parallel: Bool, cancellation: PredictionCancellation?,
        evaluate: (Input) -> Output?
    ) -> [Output?] {
        var results = [Output?](repeating: nil, count: inputs.count)
        let workers = parallel ? min(4, min(inputs.count, ProcessInfo.processInfo.activeProcessorCount)) : 1
        if workers > 1 {
            results.withUnsafeMutableBufferPointer { buffer in
                let base = buffer.baseAddress!
                DispatchQueue.concurrentPerform(iterations: workers) { worker in
                    for index in stride(from: worker, to: inputs.count, by: workers) {
                        guard cancellation?.isCancelled != true else { return }
                        (base + index).pointee = evaluate(inputs[index])
                    }
                }
            }
        } else {
            for (index, input) in inputs.enumerated() {
                guard cancellation?.isCancelled != true else { break }
                results[index] = evaluate(input)
            }
        }
        return results
    }

    struct SpinTrialKey: Hashable {
        let rails: [BankShotCalculator.Rail]
        let spin: Float
    }

    static func rank<S: RankableSolution>(_ solutions: [S], limit: Int) -> [S] {
        // Entry quality first; minimal spin within that quality, then goodness.
        let representatives = groups(solutions).map { $0.members[0] }
        return Array(representatives.sorted { lhs, rhs in
            if lhs.pocketContacts != rhs.pocketContacts { return lhs.pocketContacts < rhs.pocketContacts }
            if lhs.goodness != rhs.goodness { return lhs.goodness < rhs.goodness }
            if lhs.cushions != rhs.cushions { return lhs.cushions < rhs.cushions }
            return lhs.pathLength < rhs.pathLength
        }.prefix(limit))
    }

    /// Kept for existing bank regression callers; no aim-angle shortcut remains.
    static func isSameRefinedSolution(_ a: ShotPrediction, _ b: ShotPrediction) -> Bool {
        guard let a = BankKickRoute.measured(a, kick: false),
              let b = BankKickRoute.measured(b, kick: false) else { return false }
        return a.matches(b)
    }

    // MARK: 几何辅助

    /// 反射解首库入射角（度，相对库面）：从镜像种子首段方向计算
    /// （公式与 `DiamondSystemCalculator.firstCushionAngleOK` 同式：长库 = 常 Z，
    /// 入射角 = atan2(|dz|, |dx|)；短库对调）。
    static func kickFirstRailIncidenceDeg(
        cue: SCNVector3, target: SCNVector3,
        rails: [DiamondSystemCalculator.Rail], surfaceY: Float
    ) -> Double? {
        guard let first = rails.first,
              let seed = DiamondSystemCalculator.kickSeedPath(
                cue: cue, target: target, rails: rails, surfaceY: surfaceY),
              seed.count >= 2 else { return nil }
        let dx0 = seed[1].x - seed[0].x
        let dz0 = seed[1].z - seed[0].z
        let len = sqrtf(dx0 * dx0 + dz0 * dz0)
        guard len > 1e-6 else { return nil }
        let dx = abs(dx0 / len), dz = abs(dz0 / len)
        let angle: Float = first.isLong ? atan2(dz, dx) : atan2(dx, dz)
        return Double(angle) * 180 / .pi
    }

    /// 母球轨迹截到首次球-球碰撞点（kick 的「解线」段）。无首碰时返回全程。
    static func pathToFirstContact(_ pred: ShotPrediction) -> [SCNVector3] {
        guard let contact = pred.firstContact, pred.cuePath.count >= 2 else { return pred.cuePath }
        var bestIdx = pred.cuePath.count - 1
        var bestDist = Float.greatestFiniteMagnitude
        for (i, p) in pred.cuePath.enumerated() {
            let dx = p.x - contact.x, dz = p.z - contact.z
            let d = dx * dx + dz * dz
            if d < bestDist { bestDist = d; bestIdx = i }
        }
        return Array(pred.cuePath.prefix(bestIdx + 1))
    }

    static func polylineLengthXZ(_ path: [SCNVector3]) -> Float {
        guard path.count >= 2 else { return 0 }
        var total: Float = 0
        for i in 0..<(path.count - 1) {
            let dx = path[i + 1].x - path[i].x, dz = path[i + 1].z - path[i].z
            total += sqrtf(dx * dx + dz * dz)
        }
        return total
    }

    // MARK: 碰库点提取（画金点/法线用）

    /// 从引擎折线提取碰库点：不假设接触坐标恰在 ±halfW/±halfL（引擎接触坐标取决于
    /// 库鼻几何），改用「靠近某条库的局部极值聚类」——顶点距库线 < 2R 的连续段取
    /// 最贴库那一点。返回 (点, 指向台内的单位法向)。
    static func cushionTouchPoints(
        _ path: [SCNVector3]
    ) -> [(point: SCNVector3, inwardNormal: SCNVector3)] {
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let threshold = AngleSceneCalculator.ballRadius * 2

        struct RailProximity { let depth: Float; let normal: SCNVector3 }
        func proximity(_ p: SCNVector3) -> RailProximity? {
            // depth = 越贴库越大；四条库取最贴近者。
            var best: RailProximity?
            let candidates: [(Float, SCNVector3)] = [
                (p.z - (-halfW), SCNVector3(0, 0, 1)),   // 长库 Z=-halfW，内向 +Z
                (halfW - p.z, SCNVector3(0, 0, -1)),     // 长库 Z=+halfW，内向 -Z
                (p.x - (-halfL), SCNVector3(1, 0, 0)),   // 短库 X=-halfL，内向 +X
                (halfL - p.x, SCNVector3(-1, 0, 0))      // 短库 X=+halfL，内向 -X
            ]
            for (dist, normal) in candidates where dist < threshold {
                let depth = threshold - dist
                if best == nil || depth > best!.depth {
                    best = RailProximity(depth: depth, normal: normal)
                }
            }
            return best
        }

        var out: [(point: SCNVector3, inwardNormal: SCNVector3)] = []
        var cluster: [(SCNVector3, RailProximity)] = []
        func flush() {
            guard let deepest = cluster.max(by: { $0.1.depth < $1.1.depth }) else { return }
            out.append((deepest.0, deepest.1.normal))
            cluster.removeAll()
        }
        for p in path {
            if let prox = proximity(p) {
                // 换库（法向不同）视为新聚类。
                if let last = cluster.last, (last.1.normal.x != prox.normal.x
                    || last.1.normal.z != prox.normal.z) {
                    flush()
                }
                cluster.append((p, prox))
            } else if !cluster.isEmpty {
                flush()
            }
        }
        flush()
        return out
    }
}

protocol RankableSolution {
    var pocketContacts: Int { get }
    var contactError: Float { get }
    var spinX: Float { get }
    var route: BankKickRoute? { get }
    var searchKey: [BankShotCalculator.Rail] { get }
    var goodness: Double { get }
    var cushions: Int { get }
    var pathLength: Double { get }
    var prediction: ShotPrediction { get }
}
extension RankableSolution {
    var pocketContacts: Int { 0 }
    var contactError: Float { 0 }
}
extension BankEngineSolution: RankableSolution {
    var pocketContacts: Int { ShotPredictor.bankPocketContactCount(events: prediction.events) }
    var route: BankKickRoute? { measuredRoute ?? BankKickRoute.measured(prediction, kick: false) }
    var searchKey: [BankShotCalculator.Rail] { seedRails }
}
extension KickEngineSolution: RankableSolution {
    var contactError: Float {
        max(KickRouteQuality.centeredContactTolerance, KickRouteQuality.contactOffset(prediction))
    }
    var route: BankKickRoute? { measuredRoute ?? BankKickRoute.measured(prediction, kick: true) }
    var searchKey: [BankShotCalculator.Rail] {
        seedRails.map {
            switch $0 {
            case .left: .left
            case .right: .right
            case .far: .far
            case .near: .near
            }
        }
    }
}

// MARK: - 解缓存（LRU，方案 §4.1）

/// 小容量 LRU：精确球位、球名、力度与搜索档位；库数过滤在取出完整目录后执行。
/// 页面持有、退出释放，不落盘。任何 key 成分变化必 miss——绝不出现球形变了还展示旧解。
struct BankKickSolveCache<Key: Hashable, Value> {
    let capacity: Int
    private var entries: [(key: Key, value: Value)] = []

    init(capacity: Int = 8) { self.capacity = capacity }

    mutating func value(for key: Key) -> Value? {
        guard let idx = entries.firstIndex(where: { $0.key == key }) else { return nil }
        let entry = entries.remove(at: idx)
        entries.append(entry)   // 命中移到队尾（最新）。
        return entry.value
    }

    mutating func insert(_ value: Value, for key: Key) {
        entries.removeAll { $0.key == key }
        entries.append((key, value))
        if entries.count > capacity { entries.removeFirst() }
    }

    var count: Int { entries.count }
}

/// 两页共用的精确 key；保留量化字段供历史诊断，不能以其替代精确身份。
struct BankKickSolveKey: Hashable {
    /// 全部球位量化到毫米（顺序固定：母球 x/z、目标球 x/z、障碍球按名序）。
    let ballsMM: [Int32]
    /// 袋口 index（仅翻袋；反射恒 -1）。
    let pocketIndex: Int
    /// 力度量化到滑块步进（0.1 m/s）。
    let powerStep: Int
    /// K10：塞维度。单档 = `quantizeSpinX(spinX)`；全档搜索（默认）= `multiSpinSearchProfile`。
    let spinXCenti: Int
    var exactBallBits: [UInt32] = []
    var exactPowerBits: UInt64 = 0
    var obstacleNames: [String] = []

    /// 全档 `sideSpinSearchValues` 搜索的 key 哨兵（与单档 centi 不撞车）。
    static let multiSpinSearchProfile = 10_000

    static func quantizeMM(_ v: Float) -> Int32 { Int32((v * 1000).rounded()) }
    static func quantizePower(_ p: Double) -> Int { Int((p * 10).rounded()) }
    static func quantizeSpinX(_ s: Float) -> Int { Int((s * 100).rounded()) }

    /// 统一构造：母球/目标球 + 全部障碍球（按名序稳定排列）精确进 key——
    /// 任何球位变化（含障碍球增删挪动）必 miss（§4.1 一致性红线）。
    /// 默认 `spinXCenti = multiSpinSearchProfile`：一页一次求解覆盖全部加塞档。
    static func make(
        cue: SCNVector3, object: SCNVector3, obstacles: [ObstacleBall],
        pocketIndex: Int, power: Double,
        spinXCenti: Int = multiSpinSearchProfile
    ) -> BankKickSolveKey {
        var mm: [Int32] = [quantizeMM(cue.x), quantizeMM(cue.z),
                           quantizeMM(object.x), quantizeMM(object.z)]
        for ob in obstacles.sorted(by: { $0.name < $1.name }) {
            mm.append(quantizeMM(ob.position.x))
            mm.append(quantizeMM(ob.position.z))
        }
        return BankKickSolveKey(ballsMM: mm, pocketIndex: pocketIndex,
                                powerStep: quantizePower(power),
                                spinXCenti: spinXCenti,
                                exactBallBits: ([cue, object] + obstacles.sorted { $0.name < $1.name }.map(\.position))
                                    .flatMap { [$0.x.bitPattern, $0.y.bitPattern, $0.z.bitPattern] },
                                exactPowerBits: power.bitPattern,
                                obstacleNames: obstacles.map(\.name).sorted())
    }
}
