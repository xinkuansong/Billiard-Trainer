import CryptoKit
import Foundation
import SceneKit

/// Physical walls, independent of camera and of the two segments on each long rail.
enum BankWall: Int, Codable, CaseIterable {
    case left, right, top, bottom
    var title: String { ["左库", "右库", "上库", "下库"][rawValue] }
    private static let mainWalls: [Self?] = TableGeometry.chineseEightBallCushions(y: 0).linear.prefix(6).map { rail in
        let normal = rail.normal
        if abs(normal.x) > 0.9 { return normal.x > 0 ? .left : .right }
        if abs(normal.z) > 0.9 { return normal.z > 0 ? .top : .bottom }
        return nil
    }
    static func from(cushion index: Int?) -> Self? {
        guard let index, mainWalls.indices.contains(index) else { return nil }
        return mainWalls[index]
    }
}

/// Names follow the same fixed 2D reference as PocketDisplay, including in 3D.
enum BankRailDisplay {
    static func name(segment: Int, orientation: PocketDisplay.Orientation) -> String {
        guard let wall = BankWall.from(cushion: segment) else { return "未知库" }
        let rail = GeometricRailReference.rails[segment]
        let negativeHalf = (rail.start.x + rail.end.x) < 0
        switch (orientation, wall) {
        case (.landscape, .left): return "左短库"
        case (.landscape, .right): return "右短库"
        case (.landscape, .top): return "上长库" + (negativeHalf ? "左段" : "右段")
        case (.landscape, .bottom): return "下长库" + (negativeHalf ? "左段" : "右段")
        case (.portrait, .left): return "下短库"
        case (.portrait, .right): return "上短库"
        case (.portrait, .top): return "左长库" + (negativeHalf ? "下段" : "上段")
        case (.portrait, .bottom): return "右长库" + (negativeHalf ? "下段" : "上段")
        }
    }
}

struct BankPracticeBankQuestion: Codable, Equatable, Identifiable {
    let id: String
    let cue, target: TrainingBankPoint
    let walls: [BankWall]
    let revision: String
    let railSegments: [Int]
    let pocket: Int
    let pocketType: BankPocketType
    let direction: TrainingBankPoint
    let input: SeparationInput
    var isValid: Bool {
        let r = BallPhysics.radius
        func legal(_ p: TrainingBankPoint) -> Bool {
            p.isFinite && abs(p.x) < AngleSceneCalculator.innerLength / 2 - r
                && abs(p.z) < AngleSceneCalculator.innerWidth / 2 - r
        }
        return !id.isEmpty && (1...4).contains(walls.count) && legal(cue) && legal(target)
            && !revision.isEmpty && (0..<6).contains(pocket)
            && (pocket >= 4) == (pocketType == .middle) && railSegments.count == walls.count
            && zip(railSegments, walls).allSatisfy { BankWall.from(cushion: $0.0) == $0.1 }
            && hypot(cue.x-target.x, cue.z-target.z) > 2*r && direction.isFinite
            && abs(hypot(direction.x, direction.z)-1) < 0.0001 && input.isValid
    }
    var board: TrainingBankBoard {
        .init(gridID: id, seed: 0, cue: cue.vector, target: target.vector, aim: target.vector,
              pocket: pocket, angle: 0, side: 0, cueBand: .middle, pocketBand: .middle,
              combinationID: id, qualification: "bank-target-ordered-segments-v1", generationAngle: 0)
    }
}

enum BankPracticeBankStore {
    struct Bank: Decodable { let version: Int; let questions: [BankPracticeBankQuestion] }
    enum Failure: LocalizedError {
        case invalid(String)
        var errorDescription: String? {
            switch self { case .invalid(let reason): return "翻袋题目暂不可用：" + reason }
        }
    }
    static let fingerprint = "64539ad246523f9a09d8b8bd31a056f363216beda005f9d3cf04b72bf498426d"
    // The immutable bundled bank is decoded and validated once, including when
    // selection and prefetch run concurrently. Alternate bundles stay isolated.
    private static let bundledBank: Result<Bank, Error> = Result { try read(bundle: .main) }
    static func load(bundle: Bundle = .main) throws -> Bank {
        if bundle.bundleURL == Bundle.main.bundleURL { return try bundledBank.get() }
        return try read(bundle: bundle)
    }
    private static func read(bundle: Bundle) throws -> Bank {
        guard let url = bundle.url(forResource: "bank-practice-bank", withExtension: "json") else {
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

enum BankQuestionPreparer {
    struct Prepared { let fingerprint: String; let question: BankQuestion }
    static func prepare(_ configuration: BankConfiguration, excluding: Set<String> = [], lastContentID: String? = nil,
                        seed: UInt64 = .random(in: 0...UInt64.max)) throws -> Prepared {
        let bank = try BankPracticeBankStore.load()
        #if DEBUG
        let seed = ProcessInfo.processInfo.arguments.contains("-bank.fixedSeed") ? UInt64(31) : seed
        #endif
        var random = SceneTrainingGenerator.SeededRandom(state: seed)
        let matching = bank.questions.filter {
            (configuration.railCount == nil || $0.walls.count == configuration.railCount)
                && (configuration.pocketType == nil || $0.pocketType == configuration.pocketType)
        }
        // Prefer unseen content; a sample bundle may cycle without changing the
        // requested training length. Growing the bank does not change the UI flow.
        let unseen = matching.filter { !excluding.contains($0.id) }
        let candidates = unseen.isEmpty ? matching.filter { $0.id != lastContentID } : unseen
        // Every eligible question has equal probability; category shares follow inventory.
        guard let source = candidates.randomElement(using: &random) else {
            throw BankPracticeBankStore.Failure.invalid("未找到符合条件的题目，请重试")
        }
        try Task.checkCancellation()
        let question = BankQuestion(id: UUID(), source: source)
        return .init(fingerprint: BankPracticeBankStore.fingerprint, question: question)
    }

    static func solve(question: BankQuestion, input: SeparationInput, direction: SCNVector3,
                      surfaceY: Float, profile: [CueSection]) throws -> ShotPrediction {
        guard question.source.isValid, input.isValid, direction.x.isFinite, direction.z.isFinite,
              abs(hypot(direction.x, direction.z)-1) < 0.0001 else {
            throw BankPracticeBankStore.Failure.invalid("击球参数有误")
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
