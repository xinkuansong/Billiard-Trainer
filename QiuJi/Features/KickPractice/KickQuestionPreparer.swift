import CryptoKit
import Foundation
import SceneKit

/// Physical walls, independent of camera and of the two segments on each long rail.
enum KickWall: Int, Codable, CaseIterable {
    case left, right, top, bottom
    var title: String { ["左库", "右库", "上库", "下库"][rawValue] }
    static func from(cushion index: Int?) -> Self? {
        guard let index, (0..<6).contains(index) else { return nil }
        let normal = TableGeometry.chineseEightBallCushions(y: 0).linear[index].normal
        if abs(normal.x) > 0.9 { return normal.x > 0 ? .left : .right }
        if abs(normal.z) > 0.9 { return normal.z > 0 ? .top : .bottom }
        return nil
    }
}

struct KickBankQuestion: Codable, Equatable, Identifiable {
    let id: String
    let cue, target: TrainingBankPoint
    let walls: [KickWall]
    let direction: TrainingBankPoint
    let input: SeparationInput
    var isValid: Bool {
        let r = BallPhysics.radius
        func legal(_ p: TrainingBankPoint) -> Bool {
            p.isFinite && abs(p.x) < AngleSceneCalculator.innerLength / 2 - r
                && abs(p.z) < AngleSceneCalculator.innerWidth / 2 - r
        }
        return !id.isEmpty && (1...4).contains(walls.count) && legal(cue) && legal(target)
            && hypot(cue.x-target.x, cue.z-target.z) > 2*r && direction.isFinite
            && abs(hypot(direction.x, direction.z)-1) < 0.0001 && input.isValid
    }
    var board: TrainingBankBoard {
        .init(gridID: id, seed: 0, cue: cue.vector, target: target.vector, aim: target.vector,
              pocket: -1, angle: 0, side: 0, cueBand: .middle, pocketBand: .middle,
              combinationID: id, qualification: "kick-ordered-walls-v1", generationAngle: 0)
    }
}

enum KickBankStore {
    struct Bank: Decodable { let version: Int; let questions: [KickBankQuestion] }
    enum Failure: LocalizedError {
        case invalid(String)
        var errorDescription: String? {
            switch self { case .invalid(let reason): return "解球题目暂不可用：" + reason }
        }
    }
    static let fingerprint = "945d70489fb80b80efc807d91999830f0cfb4bf5b5d471bf048b270c56ab020d"
    // The immutable bundled bank is decoded and validated once, including when
    // selection and prefetch run concurrently. Alternate bundles stay isolated.
    private static let bundledBank: Result<Bank, Error> = Result { try read(bundle: .main) }
    static func load(bundle: Bundle = .main) throws -> Bank {
        if bundle.bundleURL == Bundle.main.bundleURL { return try bundledBank.get() }
        return try read(bundle: bundle)
    }
    private static func read(bundle: Bundle) throws -> Bank {
        guard let url = bundle.url(forResource: "kick-practice-bank", withExtension: "json") else {
            throw Failure.invalid("未找到题库")
        }
        let data = try Data(contentsOf: url)
        guard SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == fingerprint else {
            throw Failure.invalid("题库校验失败")
        }
        let bank = try JSONDecoder().decode(Bank.self, from: data)
        guard bank.version == 1, !bank.questions.isEmpty,
              Set(bank.questions.map(\.id)).count == bank.questions.count,
              bank.questions.allSatisfy(\.isValid) else { throw Failure.invalid("题库格式有误") }
        return bank
    }
}

enum KickJudgement {
    enum Failure: String, Codable {
        case incomplete = "击球计算未完成"
        case firstContact = "未解到目标球"
        case rail = "碰库顺序不符"
        case directContact = "犯规：未先碰库就碰球"
        case railFacts = "碰到了袋角或未识别的库边"
        case scratch = "母球落袋"
        case noRailAfterContact = "犯规：碰球后无球碰库"
    }
    static func failure(events: [ShotEvent], complete: Bool, walls: [KickWall], segments: [Int]? = nil) -> Failure? {
        guard complete else { return .incomplete }
        let cue = ShotInput.cueBallName
        if events.contains(where: { if case let .pocket(ball, _) = $0.kind { return ball == cue }; return false }) {
            return .scratch
        }
        var actual: [KickWall] = []
        var actualSegments: [Int] = []
        for (index, event) in events.enumerated() {
            switch event.kind {
            case .ballCushion(let ball) where ball == cue:
                guard let wall = KickWall.from(cushion: event.cushionIndex) else { return .railFacts }
                actual.append(wall); actualSegments.append(event.cushionIndex!)
            case .ballBall(let a, let b) where a == cue || b == cue:
                guard (a == cue ? b : a) == ShotInput.targetBallName else { return .firstContact }
                guard !actual.isEmpty else { return .directContact }
                // Only the final rail is optional; one-rail kicks still require a cushion.
                let full = actual == walls && (segments == nil || actualSegments == segments)
                let beforeLast = walls.count > 1 && actual == Array(walls.dropLast())
                    && (segments == nil || actualSegments == Array(segments!.dropLast()))
                guard full || beforeLast else { return .rail }
                // A pre-contact cushion (including the optional last rail) cannot
                // satisfy the separate requirement for a cushion after contact.
                let hasRailAfterContact = BankKickValidity.hasPostContactRail(events: events, afterContactAt: index)
                return hasRailAfterContact ? nil : .noRailAfterContact
            default: break
            }
        }
        return .firstContact
    }
}

enum KickQuestionPreparer {
    struct Prepared { let fingerprint: String; let question: KickQuestion }
    static func prepare(_ configuration: KickConfiguration, excluding: Set<String> = [],
                        seed: UInt64 = .random(in: 0...UInt64.max)) throws -> Prepared {
        let bank = try KickBankStore.load()
        #if DEBUG
        let seed = ProcessInfo.processInfo.arguments.contains("-kick.fixedSeed") ? UInt64(31) : seed
        #endif
        var random = SceneTrainingGenerator.SeededRandom(state: seed)
        let candidates = bank.questions.filter {
            !excluding.contains($0.id) && (configuration.railCount == nil || $0.walls.count == configuration.railCount)
        }
        guard let source = candidates.randomElement(using: &random) else {
            throw KickBankStore.Failure.invalid("本组题目已练完，请结束练习或调整库数")
        }
        try Task.checkCancellation()
        var question = KickQuestion(id: UUID(), source: source)
        // Reference replay supplies only the six-segment presentation. It never
        // admits/rejects a bank question under the player's post-contact rule.
        let prediction = try solve(question: question, input: source.input, direction: source.direction.vector,
            surfaceY: BTTablePhysics.surfaceY, profile: AccuracyTipSelector.renderedProfile())
        question.railSegments = PracticeRailColors.beforeTarget(prediction.events)
        return .init(fingerprint: KickBankStore.fingerprint, question: question)
    }

    static func solve(question: KickQuestion, input: SeparationInput, direction: SCNVector3,
                      surfaceY: Float, profile: [CueSection]) throws -> ShotPrediction {
        guard question.source.isValid, input.isValid, direction.x.isFinite, direction.z.isFinite,
              abs(hypot(direction.x, direction.z)-1) < 0.0001 else {
            throw KickBankStore.Failure.invalid("击球参数有误")
        }
        let y = surfaceY + BallPhysics.radius
        let cue = SCNVector3(question.board.cue.x, y, question.board.cue.z)
        let target = SCNVector3(question.board.target.x, y, question.board.target.z)
        let access = CueStrikeAccess(cue: cue, aim: direction, obstacles: [target], surfaceY: surfaceY, profile: profile)
        guard access.isAvailable(spinX: Double(input.spinX), spinY: Double(input.spinY)),
              access.resolvedPose(spinX: Double(input.spinX), spinY: Double(input.spinY)) != nil else {
            throw SeparationQuestionGenerator.Failure.inaccessible
        }
        return ShotPredictor.simulateFree(cueBall: cue, aimDir: direction, velocity: input.velocity,
            spinX: input.spinX, spinY: input.spinY, surfaceY: surfaceY,
            balls: [.init(name: ShotInput.targetBallName, position: target)], maxEvents: 1500, maxTime: 60,
            recordedStrikeDirection: direction)
    }
}
