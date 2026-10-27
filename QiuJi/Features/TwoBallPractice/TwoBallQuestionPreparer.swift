import Foundation
import SceneKit

struct TwoBallQuestion: Codable, Identifiable {
    struct Route: Codable {
        let source: TwoBallSourceRoute
        let recommendation: TwoBallRecommendation
        // Nil for parameter-generated references: there is no bundled offline path to compare.
        let replayRMSCM: Double?
    }
    let id: UUID
    let board: TrainingBankBoard
    let cellID: Int
    let second: TrainingBankPoint
    let routes: [Route]
    var routeIndex = 0
    var contentID: String { "\(board.id)#\(cellID)" }
    var route: Route { routes[routeIndex] }
    var target: [SeparationTrajectory.Point] { route.source.trajectory2mm.trajectory }
    var ballNumber: Int {
        let index = Int(board.seed % 14) + 1
        return index >= 8 ? index + 1 : index
    }
    var secondBallNumber: Int { 8 }
    var secondPocket: Int { route.recommendation.pocket }
    var separation: SeparationQuestion {
        .init(id: id, board: board, minimumCenterSpeed: 0.6, answer: route.source.input,
              answerDirection: .init(route.source.direction), target: target, audit: .init())
    }
}

enum TwoBallQuestionPreparer {
    static let version = "two-ball-planar-v1"
    static let secondBallName = "second"
    // Fixed before admission tests: 2 mm source compression plus 3 mm replay budget.
    static let maximumReplayRMSCM = 0.5
    struct Prepared {
        let fingerprint: String
        let question: TwoBallQuestion
        static func prepare(_ configuration: SceneTrainingConfiguration) throws -> Self {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-twoBall.fixedSeed") {
                return try TwoBallQuestionPreparer.prepare(configuration, seed: 20261025)
            }
            #endif
            return try TwoBallQuestionPreparer.prepare(configuration)
        }
    }
    static func prepare(_ configuration: SceneTrainingConfiguration, excluding: Set<String> = [],
                        seed: UInt64 = .random(in: 0...UInt64.max)) throws -> Prepared {
        let bank = try TwoBallBankStore.load()
        var random = SceneTrainingGenerator.SeededRandom(state: seed)
        let entries = bank.index.layouts.filter { bank.boards[$0.id]?.matches(configuration) == true }.shuffled(using: &random)
        let profile = renderedProfile()
        let start = Date()
        search: for entry in entries.prefix(128) {
            try Task.checkCancellation()
            guard Date().timeIntervalSince(start) < 30 else { break }
            let layout = try bank.layout(entry)
            let lookup = Dictionary(uniqueKeysWithValues: layout.routes.map { ($0.id, $0) })
            for candidate in layout.questions.shuffled(using: &random).prefix(16) {
                if excluding.contains("\(layout.id)#\(candidate.id)") { continue }
                let second = TrainingBankPoint(.init(Float(candidate.p[0]), 0, Float(candidate.p[1])))
                let board = try bank.board(for: layout)
                var routes: [TwoBallQuestion.Route] = []
                // The consumer bank is validated in ascending unrounded first-shot effort.
                // Physics/access admission only removes routes, retaining this order.
                for (rank, pair) in candidate.refs.enumerated() {
                    try Task.checkCancellation()
                    guard Date().timeIntervalSince(start) < 30 else { break search }
                    guard let route = lookup[pair[0]],
                          configuration.allowsVerticalSpin || route.sy == 0,
                          configuration.allowsSideSpin || route.sx == 0 else { continue }
                    do {
                        if let generated = try materialize(board: board, second: second, parameter: route,
                                                           pocket: pair[1], rank: rank, profile: profile) {
                            routes.append(generated)
                        }
                    } catch is CancellationError { throw CancellationError() }
                    catch { continue }
                }
                if !routes.isEmpty && zip(routes, routes.dropFirst()).allSatisfy({
                    $0.source.executionDifficulty!.effort <= $1.source.executionDifficulty!.effort + 1e-12
                }) {
                    return .init(fingerprint: bank.index.fingerprint,
                        question: .init(id: UUID(), board: board, cellID: candidate.id, second: second, routes: routes))
                }
            }
        }
        throw SeparationQuestionGenerator.Failure.unavailable
    }
    // Immutable value profile, initialized once under the lock; no SceneKit nodes escape.
    private static let profileLock = NSLock()
    private static var cachedProfile: [CueSection]?
    static func renderedProfile() -> [CueSection] {
        profileLock.lock(); defer { profileLock.unlock() }
        if let cachedProfile { return cachedProfile }
        let result = AccuracyTipSelector.renderedProfile()
        cachedProfile = result
        return result
    }
    static func prewarm() async {
        let worker = Task.detached(priority: .utility) {
            _ = try TwoBallBankStore.load()
            try Task.checkCancellation()
            _ = renderedProfile()
        }
        // Preparation reports failures to the existing settings UI on Start.
        await withTaskCancellationHandler(operation: { _ = try? await worker.value }, onCancel: { worker.cancel() })
    }
    static func materialize(board: TrainingBankBoard, second: TrainingBankPoint,
                            parameter r: TwoBallParameterRoute, pocket: Int, rank: Int,
                            profile: [CueSection]) throws -> TwoBallQuestion.Route? {
        let prediction = try solve(board: board, second: second, input: r.input,
            surfaceY: BTTablePhysics.surfaceY, profile: profile, direction: r.direction)
        guard failure(prediction, pocket: board.pocketIndex) == nil,
              !SeparationQuestionGenerator.hasCueJawContact(prediction),
              let stop = prediction.finalPositions[ShotInput.cueBallName] else { return nil }
        // Event order, not timestamp >= contact: a cushion may precede contact at the same time.
        var contacted = false, rails: [Int] = []
        for event in prediction.events {
            switch event.kind {
            case let .ballBall(a,b):
                if Set([a,b]) == Set([ShotInput.cueBallName,ShotInput.targetBallName]) { contacted = true }
            case let .ballCushion(ball):
                if ball == ShotInput.cueBallName && contacted {
                    guard let id = event.cushionIndex, (0..<6).contains(id) else { return nil }
                    rails.append(id)
                }
            default: break
            }
        }
        guard rails == r.rails, !rails.isEmpty || r.sx == 0 else { return nil }
        let cue = (Double(stop.x),Double(stop.z)), ball = (Double(second.x),Double(second.z))
        guard let comfort = TwoBallComfortScore.evaluate(cue: cue, ball: ball, pocket: pocket),
              comfort.total >= 85,
              let metric = TwoBallDifficultyMetric.evaluate(cue: cue, ball: ball, pocket: pocket) else { return nil }
        let line = try compact(SeparationTrajectory.extract(prediction), prediction: prediction, rails: rails)
        let length = zip(line.points,line.points.dropFirst()).reduce(0.0) {
            $0 + hypot($1.1[1]-$1.0[1],$1.1[2]-$1.0[2])
        }
        guard let effort = TwoBallExecutionDifficulty.evaluate(velocity: r.v, spinX: r.sx, spinY: r.sy,
                                                               cushions: rails.count, lengthMeters: length) else { return nil }
        let route = TwoBallSourceRoute(comboIndex: r.id, velocity: r.v, spinX: r.sx, spinY: r.sy,
            strikeDirection: r.dir, cueStop: [stop.x,stop.z], trajectory2mm: line,
            cueMainRailsAfterContact: rails.count, executionDifficulty: effort)
        let recommendation = TwoBallRecommendation(comboIndex: r.id, pocket: pocket,
            angle: metric.angle, distance: metric.cueDistance, score: metric.value,
            comfort: .init(distanceScore: comfort.distance, spaceScore: comfort.space,
                           angleScore: comfort.angle, totalScore: comfort.total), sourceRecommendationRank: rank)
        guard recommendation.comfort?.isQualified == true else { return nil }
        return .init(source: route, recommendation: recommendation, replayRMSCM: nil)
    }
    /// Frozen event-constrained RDP, X/Z metres, first-contact-relative seconds. No resampling of physics.
    static func compact(_ line: [SeparationTrajectory.Point], prediction: ShotPrediction,
                        rails: [Int]) throws -> TwoBallSourceRoute.Line {
    guard !line.isEmpty else { throw NSError(domain:"empty-trajectory",code:1) }
    let pts = line.map {SIMD2<Double>(Double($0.position.x),Double($0.position.z))}
    func distance(_ a:SIMD2<Double>,_ b:SIMD2<Double>)->Double {hypot(a.x-b.x,a.y-b.y)}
    func segment(_ p:SIMD2<Double>,_ a:SIMD2<Double>,_ b:SIMD2<Double>)->(Double,Double) {
        let d=b-a, ll=d.x*d.x+d.y*d.y
        let u=ll>0 ? ((p.x-a.x)*d.x+(p.y-a.y)*d.y)/ll : 0
        return (distance(p,a+d*max(0,min(1,u))),u)
    }
    let anchors=Set([0,line.count-1]+line.indices.filter{line[$0].isEvent == true}).sorted()
    var keep=Set(anchors)
    let tolerance=0.002
    func simplify(_ a:Int,_ b:Int) {
        if b<=a+1{return}
        var err = -1.0, index=a+1
        for i in (a+1)..<b {
            let d=segment(pts[i],pts[a],pts[b]).0
            if d>=err {err=d;index=i}
        }
        var maxu=0.0,maxi=a
        let chord=distance(pts[a],pts[b])
        for i in (a+1)..<b {
            let u=segment(pts[i],pts[a],pts[b]).1
            if (maxu-u)*chord>tolerance && maxi>a && maxi<b {index=maxi;err=max(err,tolerance*2);break}
            if u>maxu {maxu=u;maxi=i}
        }
        if err>tolerance {keep.insert(index);simplify(a,index);simplify(index,b)}
    }
    for (a,b) in zip(anchors,anchors.dropFirst()) {simplify(a,b)}
    let indices=keep.sorted()
    var maxError=0.0
    for (a,b) in zip(indices,indices.dropFirst()) {
        for i in a...b {maxError=max(maxError,segment(pts[i],pts[a],pts[b]).0)}
    }
    guard maxError<=tolerance+1e-12,
          let end=prediction.finalPositions[ShotInput.cueBallName],
          distance(pts.last!,SIMD2(Double(end.x),Double(end.z)))<0.000001 else {
        throw NSError(domain:"compression-audit",code:2)
    }
    try Task.checkCancellation()
    return .init(coordinateUnit: "meter-XZ", timeOrigin: "firstTargetContact",
        points: indices.map { [Double(line[$0].time),pts[$0].x,pts[$0].y] },
        mandatoryPointIndices: indices.indices.filter { anchors.contains(indices[$0]) },
        cushions: rails.map { .init(cushionID: $0) })
    }
    static func solve(board: TrainingBankBoard, second: TrainingBankPoint, input: SeparationInput,
                      surfaceY: Float, profile: [CueSection], direction saved: SCNVector3? = nil) throws -> ShotPrediction {
        try Task.checkCancellation()
        guard input.isValid, EventDrivenEngine.SimulationModel.appDefault == .planarReference else {
            throw SeparationQuestionGenerator.Failure.incompatible
        }
        let direction: SCNVector3
        if let saved { direction = saved }
        else {
            let aim = try SeparationQuestionGenerator.solve(board: board, input: input, surfaceY: surfaceY, profile: profile)
            guard let solved = aim.strikeDirection else { throw SeparationQuestionGenerator.Failure.incomplete }
            direction = solved
        }
        let y = surfaceY + BallPhysics.radius
        let access = CueStrikeAccess(cue: .init(board.cue.x,y,board.cue.z), aim: direction,
            obstacles: [.init(board.target.x,y,board.target.z), .init(second.x,y,second.z)], surfaceY: surfaceY, profile: profile)
        guard access.isAvailable(spinX: Double(input.spinX), spinY: Double(input.spinY)),
              access.resolvedPose(spinX: Double(input.spinX), spinY: Double(input.spinY)) != nil else {
            throw SeparationQuestionGenerator.Failure.inaccessible
        }
        let result = ShotPredictor.simulateFree(cueBall: board.cue.vector, aimDir: direction,
            velocity: input.velocity, spinX: input.spinX, spinY: input.spinY, surfaceY: surfaceY,
            balls: [.init(name: ShotInput.targetBallName, position: board.target.vector),
                    .init(name: secondBallName, position: second.vector)], maxEvents: 1500, maxTime: 60,
            recordedStrikeDirection: direction)
        try Task.checkCancellation()
        guard result.hasFinalTableState, result.recorder != nil,
              result.finalPositions.values.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }) else {
            throw SeparationQuestionGenerator.Failure.incomplete
        }
        return result
    }
    static func failure(_ prediction: ShotPrediction, pocket: Int) -> String? {
        if prediction.events.contains(where: {
            if case let .ballBall(a,b) = $0.kind { return a == secondBallName || b == secondBallName }
            return false
        }) || prediction.pocketedBalls.contains(secondBallName) { return "碰动第二球" }
        if prediction.pocketedBalls.contains(ShotInput.cueBallName) { return "母球落袋" }
        guard prediction.recorder?.firstBallContacts[ShotInput.cueBallName]?.other.name == ShotInput.targetBallName else {
            return "未先碰第一球"
        }
        if !SeparationQuestionGenerator.potsSpecifiedPocket(prediction, pocket: pocket) { return "第一球未进指定袋" }
        return nil
    }
}

/// Reuses the durable multi-ball frame codec; business judgement remains independent.
@dynamicMemberLookup
struct TwoBallShot: Codable, Identifiable {
    var physical: SeparationShot
    let comboIndex: Int
    let secondPocket: Int
    let failure: String?
    let difficulty: TwoBallDifficultyMetric.Result?
    // Optional for records written before comfort scoring; never reinterpret legacy difficulty.
    var comfort: TwoBallComfortScore.Result?
    var comfortVersion: String?
    // Absent in old records: their saved score remains unchanged.
    var continuationUnavailable: Bool?
    var id: UUID { physical.id }
    subscript<T>(dynamicMember key: KeyPath<SeparationShot,T>) -> T { physical[keyPath: key] }
    var playsStroke: Bool? { get { physical.playsStroke } set { physical.playsStroke = newValue } }
    var trajectoryScore: Double { failure == nil ? physical.score?.value ?? 0 : 0 }
    var freeScore: Double? {
        // Historical scores are frozen snapshots, not recomputed with the current curve.
        guard comfortVersion == TwoBallComfortScore.version
                || comfortVersion == TwoBallComfortScore.freePositionVersion else { return nil }
        return failure == nil && continuationUnavailable != true ? comfort?.total ?? 0 : 0
    }
    init(question: TwoBallQuestion, input: SeparationInput, prediction: ShotPrediction, surfaceY: Float) throws {
        physical = try .init(question: question.separation, input: input, prediction: prediction, surfaceY: surfaceY)
        comboIndex = question.route.source.comboIndex; secondPocket = question.secondPocket
        failure = TwoBallQuestionPreparer.failure(prediction, pocket: question.board.pocketIndex)
        if failure == nil, let cue = prediction.finalPositions[ShotInput.cueBallName] {
            difficulty = TwoBallDifficultyMetric.evaluate(cue: (Double(cue.x),Double(cue.z)),
                ball: (Double(question.second.x),Double(question.second.z)), pocket: secondPocket)
        } else { difficulty = nil }
        comfortVersion = TwoBallComfortScore.freePositionVersion
        if failure == nil, let cue = prediction.finalPositions[ShotInput.cueBallName] {
            comfort = TwoBallComfortScore.evaluateFreePosition(cue: (Double(cue.x), Double(cue.z)),
                ball: (Double(question.second.x), Double(question.second.z)), pocket: secondPocket)
            let target = question.second.vector
            let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: secondPocket, surfaceY: surfaceY)
            continuationUnavailable = comfort == nil || !AngleSceneCalculator.isFeasible(cueBall: cue, targetBall: target, pocket: aim)
        }
    }
    func prediction() -> ShotPrediction { physical.prediction() }
    func resultText(mode: TwoBallMode) -> String {
        if failure == "第一球未进指定袋" || (mode == .free && continuationUnavailable == true) {
            return TrainingPracticeNotice.cannotPot
        }
        if let failure { return "本杆0分 · \(failure)" }
        if mode == .trajectory { return String(format: "本杆%.1f分 · 第一球进指定袋", trajectoryScore) }
        if let freeScore { return String(format: "本杆得分 %.1f 分", freeScore) }
        guard let difficulty else { return "无正向直击线路" }
        return String(format: "旧版难度 %.3f", difficulty.value)
    }
}

/// Distance v2 / directional clearance v3. Bank admission keeps angle v2 and geometric mean;
/// free-position shots use the approved pocket-distance 20-degree curve and 50% minimum weighting.
/// X/Z metres, Y up. Uses the research's frozen rectangular geometry and pocket anchors,
/// not a substitute for physical pocket feasibility or a probability of potting.
enum TwoBallComfortScore {
    static let version = "comfort-d2-s3-a2-v1"
    static let freePositionVersion = "comfort-d2-s3-pocket-angle20-min50-v1"
    struct Result: Codable {
        enum Aggregation: String, Codable { case minimumWeighted }
        let distance, space, angle, total: Double
        // Absent in historical snapshots, which used the geometric mean.
        var aggregation: Aggregation? = nil
        var details: String {
            let formula = aggregation == .minimumWeighted
                ? "总分 = 0.5 × 三项最低分 + 0.5 × 三项几何平均，越高越好。"
                : "总分为三项等权几何平均，越高越好。"
            return String(format: "球距分 %.1f\n出杆空间分 %.1f\n角度分 %.1f\n\n", distance, space, angle)
                + formula + "\n评价下一杆的舒适度，不代表进球概率。"
        }
    }
    static func evaluate(cue: (Double, Double), ball: (Double, Double), pocket: Int,
                         geometry g: TwoBallDifficultyMetric.Geometry = .source) -> Result? {
        evaluate(cue: cue, ball: ball, pocket: pocket, geometry: g, pocketDistanceAngle: false)
    }
    static func evaluateFreePosition(cue: (Double, Double), ball: (Double, Double), pocket: Int,
                                     geometry g: TwoBallDifficultyMetric.Geometry = .source) -> Result? {
        evaluate(cue: cue, ball: ball, pocket: pocket, geometry: g, pocketDistanceAngle: true)
    }
    private static func evaluate(cue: (Double, Double), ball: (Double, Double), pocket: Int,
                                 geometry g: TwoBallDifficultyMetric.Geometry, pocketDistanceAngle: Bool) -> Result? {
        guard let p = g.anchor(pocket),
              let score = ShotComfortScore.evaluate(cue: cue, ball: ball, aim: p,
                  geometry: .init(length: g.length, width: g.width, radius: g.radius),
                  pocketDistanceAngle: pocketDistanceAngle) else { return nil }
        return .init(distance: score.distance, space: score.space, angle: score.angle, total: score.total,
                     aggregation: pocketDistanceAngle ? .minimumWeighted : nil)
    }
}
