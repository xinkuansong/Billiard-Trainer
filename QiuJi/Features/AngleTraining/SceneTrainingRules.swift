import Foundation
import SceneKit

/// Four scene quizzes share metre-based conditions. Legacy abstract quizzes keep their own rules.
struct SceneTrainingConfiguration: Codable, Equatable {
    enum AngleRange: String, Codable, CaseIterable, Identifiable {
        case straight, small, medium, large, thin, mixed
        var id: String { rawValue }
        var degrees: ClosedRange<Int> {
            switch self {
            case .straight: 0...10
            case .small: 11...30
            case .medium: 31...50
            case .large: 51...70
            case .thin: 71...85
            case .mixed: 0...70
            }
        }
        var label: String {
            switch self {
            case .straight: "近直球 · 0–10°"
            case .small: "小角度 · 11–30°"
            case .medium: "中角度 · 31–50°"
            case .large: "大角度 · 51–70°"
            case .thin: "极薄球 · 71–85°"
            case .mixed: "综合 · 0–70°"
            }
        }
    }
    enum Distance: String, Codable, CaseIterable, Identifiable {
        case short, middle, long, mixed
        var id: String { rawValue }
        func metres(cue: Bool) -> ClosedRange<Double> {
            switch self {
            case .short: (cue ? 0.30 : 0.25)...0.60
            case .middle: 0.600001...1.20
            case .long: 1.200001...1.80
            case .mixed: (cue ? 0.30 : 0.25)...1.80
            }
        }
        func label(cue: Bool) -> String {
            switch self {
            case .short: "短 · \(cue ? "0.30" : "0.25")–0.60m"
            case .middle: "中 · >0.60–1.20m"
            case .long: "长 · >1.20–1.80m"
            case .mixed: "混合（可行档位）"
            }
        }
        var bands: [Self] { self == .mixed ? [.short, .middle, .long] : [self] }
    }
    enum Pockets: String, Codable, CaseIterable, Identifiable {
        case mixed, corner, side
        var id: String { rawValue }
        var label: String { switch self { case .mixed: "混合"; case .corner: "角袋"; case .side: "中袋" } }
    }
    var freePractice = false
    var angles: AngleRange = .mixed
    var cueDistance: Distance = .mixed
    var pocketDistance: Distance = .mixed
    var pockets: Pockets = .mixed
    // Start the revised defaults once for every route, then retain new user choices.
    static func load(for route: String) -> Self {
        guard let data = UserDefaults.standard.data(forKey: "sceneTraining.rules2.mixedDefaults." + route),
              let value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return value
    }
    func save(for route: String) {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "sceneTraining.rules2.mixedDefaults." + route)
        }
    }
}

struct SceneTrainingQuestion {
    let id: UUID
    let geometry: AngleQuestion
    let side: Int
    let cueBand: SceneTrainingConfiguration.Distance
    let pocketBand: SceneTrainingConfiguration.Distance
}

/// Bounded, reproducible generation. Never clamps a ball or substitutes another requested condition.
struct SceneTrainingGenerator {
    struct GenerationError: LocalizedError {
        var errorDescription: String? { "当前角度与距离组合暂无可用球形。请重新生成，或调整球形条件。" }
    }
    struct SeededRandom: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9e3779b97f4a7c15
            var value = state
            value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
            value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
            return value ^ (value >> 31)
        }
    }
    var random: SeededRandom
    init(seed: UInt64 = UInt64.random(in: 0...UInt64.max)) { random = .init(state: seed) }

    mutating func batch(_ config: SceneTrainingConfiguration, previousAngle: Int? = nil) throws -> [SceneTrainingQuestion] {
        var angles: [Int] = []
        let allocations: [(SceneTrainingConfiguration.AngleRange, Int)] = config.angles == .mixed
            ? [(.straight, 2), (.small, 6), (.medium, 6), (.large, 6)] : [(config.angles, 20)]
        for (range, count) in allocations {
            var pool: [Int] = []
            while pool.count < count { pool += Array(range.degrees).shuffled(using: &random) }
            angles += pool.prefix(count)
        }
        for _ in 0..<128 {
            angles.shuffle(using: &random)
            if angles.first != previousAngle && zip(angles, angles.dropFirst()).allSatisfy({ $0 != $1 }) { break }
        }
        guard angles.first != previousAngle, zip(angles, angles.dropFirst()).allSatisfy({ $0 != $1 }) else {
            throw GenerationError()
        }
        var corners = [0, 1, 2, 3].shuffled(using: &random)
        var sides = [4, 5].shuffled(using: &random)
        let cornerCount = config.pockets == .side ? 0 : (config.pockets == .mixed ? 10 : 20)
        while corners.count < cornerCount { corners += [0, 1, 2, 3].shuffled(using: &random) }
        while sides.count < 20 - cornerCount { sides += [4, 5].shuffled(using: &random) }
        var pockets = Array(corners.prefix(cornerCount)) + Array(sides.prefix(20 - cornerCount))
        pockets.shuffle(using: &random)
        let nonZero = angles.filter { $0 != 0 }.count
        var cuts = (0..<nonZero).map { $0 % 2 == 0 ? 1 : -1 }.shuffled(using: &random)
        var output: [SceneTrainingQuestion] = []
        var used: Set<String> = []
        var bandUse: [String: Int] = [:]
        for index in 0..<20 {
            let side = angles[index] == 0 ? 0 : cuts.removeLast()
            // Mixed only searches explicitly selected bands; least-used feasible pairs go first.
            let pairs = config.cueDistance.bands.flatMap { cue in config.pocketDistance.bands.map { (cue, $0) } }
                .shuffled(using: &random).sorted { bandUse[$0.0.rawValue + $0.1.rawValue, default: 0] < bandUse[$1.0.rawValue + $1.1.rawValue, default: 0] }
            var generated: SceneTrainingQuestion?
            for (cueBand, pocketBand) in pairs {
                if let question = question(angle: angles[index], side: side, pocket: pockets[index], cueBand: cueBand, pocketBand: pocketBand) {
                    let q = question.geometry
                    let key = "\(q.pocketIndex):\(q.cueBall):\(q.targetBall)"
                    guard used.insert(key).inserted else { continue }
                    generated = question
                    bandUse[cueBand.rawValue + pocketBand.rawValue, default: 0] += 1
                    break
                }
            }
            guard let generated else { throw GenerationError() }
            output.append(generated)
        }
        return output
    }

    mutating func question(angle: Int, side: Int, pocket: Int,
                          cueBand: SceneTrainingConfiguration.Distance,
                          pocketBand: SceneTrainingConfiguration.Distance) -> SceneTrainingQuestion? {
        let r = Double(AngleSceneCalculator.ballRadius)
        let length = Double(AngleSceneCalculator.innerLength)
        let width = Double(AngleSceneCalculator.innerWidth)
        let cueRange = cueBand.metres(cue: true), pocketRange = pocketBand.metres(cue: false)
        let nominal = AngleSceneCalculator.pocketPositions(surfaceY: 0)[pocket]
        let theta = Double(angle) * .pi / 180
        for _ in 0..<600 {
            // Polar sampling places targets in the requested distance annulus before expensive jaw checks.
            let bearing = Double.random(in: 0...(2 * .pi), using: &random)
            let radius = Double.random(in: pocketRange, using: &random)
            let target = SCNVector3(nominal.x + Float(radius * cos(bearing)), 0,
                                    nominal.z + Float(radius * sin(bearing)))
            func inside(_ p: SCNVector3) -> Bool {
                abs(Double(p.x)) < length / 2 - r - 0.015 && abs(Double(p.z)) < width / 2 - r - 0.015
            }
            guard inside(target) else { continue }
            let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocket, surfaceY: 0)
            let targetDistance = Double(AngleSceneCalculator.horizontalDistance(target, aim))
            guard pocketRange.contains(targetDistance) else { continue }
            let heading = atan2(Double(aim.z - target.z), Double(aim.x - target.x))
            let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: Float(r))
            guard inside(ghost) else { continue }
            let centerDistance = Double.random(in: cueRange, using: &random)
            // |T-C|² = s² + 4R cos(theta)s + 4R²; s is cue-to-ghost distance.
            let s = sqrt(centerDistance * centerDistance - 4 * r * r * sin(theta) * sin(theta)) - 2 * r * cos(theta)
            let approach = heading + Double(side) * theta
            let cue = SCNVector3(ghost.x - Float(s * cos(approach)), 0, ghost.z - Float(s * sin(approach)))
            guard inside(cue), s > 0,
                  AngleSceneCalculator.trainingHasCleanPocketPath(target: target, aim: aim, pocketIndex: pocket) else { continue }
            let measured = AngleSceneCalculator.cutAngle(cueBall: cue, targetBall: target, pocket: aim)
            let measuredDistance = Double(AngleSceneCalculator.horizontalDistance(cue, target))
            guard abs(measured - Double(angle)) <= 0.05, cueRange.contains(measuredDistance) else { continue }
            let question = AngleQuestion(targetBall: AngleSceneCalculator.sceneToNormalized(position: target),
                cueBall: AngleSceneCalculator.sceneToNormalized(position: cue), pocket: AngleCalculator.pockets[pocket],
                // Geometry has passed the 0.05° check. Use the sampled integer as the answer
                // so Float noise cannot turn a displayed 3.0° boundary into a failing grade.
                actualAngle: Double(angle), pocketType: pocket < 4 ? .corner : .side, pocketIndex: pocket)
            return .init(id: UUID(), geometry: question, side: side, cueBand: cueBand, pocketBand: pocketBand)
        }
        return nil
    }
}

struct SceneAimScore: Codable, Equatable {
    enum Status: String, Codable { case valid, backwards, wrongSide, missesTarget }
    let status: Status
    let millimetres: Double?
    let straight: Bool
    var label: String {
        guard let mm = millimetres, status == .valid else {
            switch status { case .backwards: return "方向反了"; case .wrongSide: return "瞄错侧"; default: return "未对准目标球" }
        }
        if abs(mm) < 0.05 { return "一致" }
        if straight { return mm > 0 ? "偏左" : "偏右" }
        return mm > 0 ? "偏薄" : "偏厚"
    }
    static func measure(cue: SCNVector3, target: SCNVector3, ghost: SCNVector3, direction: SCNVector3) -> Self {
        let cx = Double(cue.x), cz = Double(cue.z)
        let gx = Double(ghost.x), gz = Double(ghost.z)
        let distance = hypot(gx - cx, gz - cz)
        let norm = hypot(Double(direction.x), Double(direction.z))
        guard distance > 1e-9, norm > 1e-9 else { return .init(status: .backwards, millimetres: nil, straight: false) }
        let ux = (gx - cx) / distance, uz = (gz - cz) / distance
        let vx = Double(direction.x) / norm, vz = Double(direction.z) / norm
        let dot = vx * ux + vz * uz
        let tx = Double(target.x) - cx, tz = Double(target.z) - cz
        var nx = -uz, nz = ux
        let targetSide = (Double(target.x) - gx) * nx + (Double(target.z) - gz) * nz
        let straight = abs(targetSide) < 0.00001
        if !straight && targetSide > 0 { nx = -nx; nz = -nz }
        guard dot > 0.000001, tx * vx + tz * vz > 0 else { return .init(status: .backwards, millimetres: nil, straight: straight) }
        let userSide = vx * tz - vz * tx
        let correctSide = ux * tz - uz * tx
        if !straight && abs(userSide) > 0.000001 && userSide * correctSide < 0 {
            return .init(status: .wrongSide, millimetres: nil, straight: false)
        }
        guard abs(userSide) <= Double(2 * AngleSceneCalculator.ballRadius) + 1e-7 else {
            return .init(status: .missesTarget, millimetres: nil, straight: straight)
        }
        let t = distance / dot
        let mm = ((cx + vx * t - gx) * nx + (cz + vz * t - gz) * nz) * 1000
        return .init(status: .valid, millimetres: mm, straight: straight)
    }
}

struct SceneTrainingMetadata: Codable {
    let rulesVersion: Int
    let scoringVersion: String
    let unit: String
    let runID: UUID
    let questionID: UUID
    let configuration: SceneTrainingConfiguration
    let cue: [Double]
    let target: [Double]
    let effectiveAim: [Double]
    let ghost: [Double]
    let coordinateSpace: String
    let pocketIndex: Int
    let angle: Double
    let firstAttempt: Bool
    let assistance: [String]
    let userDirection: [Double]?
    let score: SceneAimScore?
    var independent: Bool { firstAttempt && assistance.isEmpty }
    var json: String? { (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) } }
}

struct SceneTrainingRun {
    var id = UUID()
    var configuration = SceneTrainingConfiguration()
    var queue: [SceneTrainingQuestion] = []
    var coveredCueBands: Set<SceneTrainingConfiguration.Distance> = []
    var coveredPocketBands: Set<SceneTrainingConfiguration.Distance> = []
    var current: SceneTrainingQuestion?
    var assistance: Set<String> = []
    var firstAnswers: [SceneTrainingSample] = []
    var submitted = false
    var canFinish: Bool { !configuration.freePractice && firstAnswers.count >= 20 }
    mutating func next() throws -> AngleQuestion {
        if queue.isEmpty {
            var generator = SceneTrainingGenerator()
            queue = try generator.batch(configuration, previousAngle: current.map { Int($0.geometry.actualAngle.rounded()) })
        }
        coveredCueBands.formUnion(queue.map(\.cueBand))
        coveredPocketBands.formUnion(queue.map(\.pocketBand))
        current = queue.removeFirst()
        assistance = []; submitted = false
        return current!.geometry
    }
    func metadata(unit: String, direction: SCNVector3? = nil, score: SceneAimScore? = nil) -> SceneTrainingMetadata? {
        guard let current else { return nil }
        let q = current.geometry
        let target = AngleSceneCalculator.normalizedToScene(point: q.targetBall, surfaceY: 0)
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: q.pocketIndex, surfaceY: 0)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: AngleSceneCalculator.ballRadius)
        let aimPoint = AngleSceneCalculator.sceneToNormalized(position: aim)
        let ghostPoint = AngleSceneCalculator.sceneToNormalized(position: ghost)
        return .init(rulesVersion: 2, scoringVersion: unit == "mm" ? "transverse-v2" : "angle-v2", unit: unit,
            runID: id, questionID: current.id, configuration: configuration,
            cue: [q.cueBall.x, q.cueBall.y], target: [q.targetBall.x, q.targetBall.y], effectiveAim: [aimPoint.x, aimPoint.y],
            ghost: [ghostPoint.x, ghostPoint.y], coordinateSpace: "tableNormalized-2.54m-XZ", pocketIndex: q.pocketIndex,
            angle: q.actualAngle, firstAttempt: true, assistance: assistance.sorted(),
            userDirection: direction.map { [Double($0.x), Double($0.z)] }, score: score)
    }
    mutating func record(error: Double?, signedError: Double?, angle: Double) {
        guard !submitted else { return }
        firstAnswers.append(.init(angle: angle, error: error, signedError: signedError, assisted: !assistance.isEmpty))
        submitted = true
    }
    var coverage: String {
        func names(_ bands: Set<SceneTrainingConfiguration.Distance>) -> String {
            SceneTrainingConfiguration.Distance.allCases.filter { bands.contains($0) }
                .map { $0 == .short ? "短" : $0 == .middle ? "中" : "长" }.joined(separator: "/")
        }
        return "本轮母球：" + names(coveredCueBands) + "；距袋：" + names(coveredPocketBands)
    }
}

struct SceneTrainingSample {
    let angle: Double
    let error: Double?
    let signedError: Double?
    let assisted: Bool
}
