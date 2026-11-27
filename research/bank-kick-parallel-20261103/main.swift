import Foundation
import SceneKit

setbuf(stdout, nil)
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let y: Float = 0.8
func point(_ x: Float, _ z: Float) -> SCNVector3 { .init(x, y + BallPhysics.radius, z) }
func impact(_ prediction: ShotPrediction) -> Float {
    guard let c = prediction.recorder?.firstBallContacts[ShotInput.cueBallName] else { return 1 }
    let d = c.other.position - c.incoming.position
    let v = c.incoming.velocity
    return min(1, abs(d.x * v.z - d.z * v.x) / (hypotf(d.x,d.z) * hypotf(v.x,v.z)))
}
func postContactRail(_ p: ShotPrediction) -> Bool {
    guard let contact = p.events.first(where: {
        if case let .ballBall(a,b) = $0.kind { return a == ShotInput.cueBallName || b == ShotInput.cueBallName }
        return false
    }) else { return false }
    return p.events.contains { e in
        if case let .ballCushion(ball) = e.kind {
            return e.time > contact.time && [ShotInput.cueBallName,ShotInput.targetBallName].contains(ball)
        }
        return false
    }
}
var checks = 0
func check(_ ok: Bool, _ message: String) {
    checks += 1
    if !ok { fatalError(message) }
}

func XCTAssertTrue(_ value: Bool, _ message: String = "") { check(value, message) }
func XCTAssertNil<T>(_ value: T?, _ message: String = "") { check(value == nil, message) }
func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "") { check(a == b, message) }
let matrix = BankKickParallelRailTests()
matrix.testEverySequenceUpToFourContacts()
matrix.testEventScopeAndBothValidationPaths()

// Independent event oracle based on physical main segment IDs (0/1, 2/3, 4, 5).
func hasParallelPair(_ prediction: ShotPrediction, kick: Bool) -> Bool {
    var active = kick
    var walls: [Int] = []
    for e in prediction.events {
        if case let .ballBall(a,b) = e.kind, a == ShotInput.cueBallName || b == ShotInput.cueBallName {
            if kick { break }; active = true
        }
        if case .pocket(let ball, _) = e.kind, !kick && ball == ShotInput.targetBallName { break }
        if active, case .ballCushion(let ball) = e.kind,
           ball == (kick ? ShotInput.cueBallName : ShotInput.targetBallName),
           let index = e.cushionIndex, (0..<6).contains(index) {
            walls.append(index < 4 ? index / 2 : index - 2)
        }
    }
    let opposite = [0:1,1:0,2:3,3:2]
    return zip(walls,walls.dropFirst()).contains { opposite[$0.0] == $0.1 }
}

#if CENTERED_CHECK
struct Candidate: RankableSolution {
    var spinX: Float
    var contactError: Float
    var route: BankKickRoute?
    var searchKey: [BankShotCalculator.Rail] = [.left]
    var goodness: Double = 0
    var cushions: Int { route?.rails.count ?? 0 }
    var pathLength: Double = 1
    var prediction = ShotPrediction()
}
let r = BankKickRoute(rails: [.left,.near], contacts: [], path: [], pocketID: nil)
check(r.matches(.init(rails: [.left,.near], contacts: [point(0.5,0.3)], path: [], pocketID: nil)), "Same sequence merges")
check(!r.matches(.init(rails: [.near,.left], contacts: [], path: [], pocketID: nil)), "Order is distinct")
check(!r.matches(.init(rails: [.left], contacts: [], path: [], pocketID: nil)), "Count is distinct")
let square = Candidate(spinX: 0.3, contactError: 0.01, route: r)
let thin = Candidate(spinX: 0, contactError: 0.8, route: r)
check(BankKickSolvePipeline.rank([thin,square], limit: 16).first?.spinX == 0.3, "Square before low spin")
check(BankKickSolvePipeline.rank([thin], limit: 16).count == 1, "Thin fallback remains")
let reduced = BankKickSolvePipeline.minimumSpinRepresentatives([square], spinXValues: [0,0.3]) { seed, sx in
    var trial = seed; trial.spinX = sx; trial.contactError = sx < 10 * BankKickSolvePipeline.minimumSpinStep ? 0.8 : 0.01; return trial
}
check(abs(reduced[0].spinX-0.2) < 0.0001, "Spin reduction preserves square contact")
for degrees: Float in [0,30,60,89] {
    let a = degrees * .pi / 180
    let ball = BallState(position: point(0,0), velocity: SCNVector3(cosf(a),0,sinf(a)),
                         angularVelocity: SCNVector3Zero, state: .rolling, name: ShotInput.cueBallName)
    check(abs(KickRouteQuality.contactOffset(incoming: ball, target: point(2*BallPhysics.radius,0))-sinf(a)) < 0.00001,
          "Independent known angle")
}
#endif

// Exercise both tool and practice consumers using the same event boundary cases.
let cueName = ShotInput.cueBallName, targetName = ShotInput.targetBallName
let before = ShotEvent(time: 1, kind: .ballCushion(ball: cueName), contactNormal: .init(0,0,1), cushionIndex: 0)
let hit = ShotEvent(time: 2, kind: .ballBall(ballA: cueName, ballB: targetName))
let postCases: [(String,[ShotEvent],Bool)] = [
    ("no rail",[],false),
    ("cue rail",[.init(time:3,kind:.ballCushion(ball:cueName),cushionIndex:0)],true),
    ("target rail",[.init(time:3,kind:.ballCushion(ball:targetName),cushionIndex:2)],true),
    ("same timestamp",[.init(time:2,kind:.ballCushion(ball:cueName),cushionIndex:0)],false),
    ("older timestamp",[.init(time:1.5,kind:.ballCushion(ball:targetName),cushionIndex:0)],false),
    ("unrelated ball",[.init(time:3,kind:.ballCushion(ball:"block"),cushionIndex:0)],false),
    ("target pocket only",[.init(time:3,kind:.pocket(ball:targetName,pocketId:"pocket_0"))],false),
    ("post jaw",[.init(time:3,kind:.ballCushion(ball:cueName),cushionIndex:6)],true)
]
for (name,tail,expected) in postCases {
    var p = ShotPrediction(); p.termination = .settled; p.events = [before,hit]+tail
    check(BankKickValidity.kick(p)==expected,name)
    check(KickRouteQuality.accepts(p)==expected,"quality: \(name)")
    check(BankKickValidity.kick(BankKickValidation(p))==expected,"compact facts: \(name)")
    let practice = KickJudgement.failure(events:p.events,complete:true,walls:[KickWall.from(cushion:0)!])
    check((practice == nil)==expected,"practice parity: \(name)")
    if expected {
        p.cuePocketed=true
        check(!BankKickValidity.kick(p),"scratch")
        p.cuePocketed=false; p.termination = .timeLimit
        check(!BankKickValidity.kick(p),"unfinished")
    }
}
var rejectedRealContacts = 0
for x: Float in [0.1,0.3,0.5] {
    for power: Float in [0.5,0.6,0.8,1.0,1.2,1.4] {
        var input = ShotInput(cueBall:point(-0.2,0.45),targetBall:point(x,0.45),pocketIndex:0,
            velocity:power,spinX:0,spinY:0,surfaceY:y)
        input.kickRails = [.right]
        let p = ShotPredictor.predict(input,includeBankKickPresentation:false)
        let contact = ShotPredictor.kickContactInfo(events:p.events)
        if p.termination == .settled && !p.cuePocketed && contact.contacted && contact.cushionsBefore > 0 && !postContactRail(p) {
            rejectedRealContacts += 1
            check(!BankKickValidity.kick(p),"Real stopped-after-contact foul must fail")
            check(BankKickSolvePipeline.kickSolution(input:input,seedRails:[.right],prediction:p,measureRobustness:false)==nil,"Foul must not enter catalog")
        }
    }
}
check(rejectedRealContacts>0,"Must exercise real no-post-contact-rail shots")
print("REAL_NO_POST_RAIL_REJECTED \(rejectedRealContacts)")

let cases: [(String,SCNVector3,SCNVector3,Float,[ObstacleBall])] = [
    ("screenshot-approx",point(0.68,0.28),point(-1.07,-0.27),2.4,[]),
    ("mirror-x",point(-0.68,0.28),point(1.07,-0.27),2.4,[]),
    ("mirror-z",point(0.68,-0.28),point(-1.07,0.27),2.4,[]),
    ("parallel-screenshot-approx",point(0.68,0.28),point(-0.57,-0.19),2.4,[]),
    ("ordinary",point(-0.5,-0.2),point(0.4,0.25),3.6,[]),
    ("ordinary-slow",point(-0.5,-0.2),point(0.4,0.25),2.0,[]),
    ("weak",point(-0.5,-0.2),point(0.4,0.25),0.5,[]),
    ("middle",point(-0.8,0.15),point(0.0,-0.38),2.4,[]),
    ("obstacle",point(0.68,0.28),point(-1.07,-0.27),2.4,[.init(name:"block",position:point(-0.3,0.15))])
]
var rows: [[String:Any]] = []
for (name,cue,target,power,obstacles) in cases {
    let start = Date()
    let solutions = BankKickSolvePipeline.solveKick(cue:cue,target:target,surfaceY:y,power:power,obstacles:obstacles,limit:nil)
    let elapsed = Date().timeIntervalSince(start)
    var identities = Set<String>()
    var data: [[String:Any]] = []
    for sol in solutions {
        let key = sol.rails.map { String(describing:$0) }.joined(separator:",")
        #if CENTERED_CHECK
        check(identities.insert(key).inserted,"Duplicate route: \(name) \(key)")
        check(KickRouteQuality.accepts(sol.prediction),"Invalid recommendation")
        check(!hasParallelPair(sol.prediction,kick:true),"Parallel kick route leaked")
        check(postContactRail(sol.prediction),"Recommended shot has no post-contact cushion")
        check(abs(KickRouteQuality.contactOffset(sol.prediction)-impact(sol.prediction)) < 0.00001,"Measured impact")
        if name.hasPrefix("screenshot") && sol.rails == [.right] {
            check(impact(sol.prediction) <= KickRouteQuality.centeredContactTolerance,"Screenshot approximate one-rail must be centered")
        }
        #endif
        data.append(["rails":key,"impact":impact(sol.prediction),"spin":sol.spinX,
                     "path":sol.measuredRoute!.path.map { [Double($0.x),Double($0.z)] },
                     "aim":[sol.prediction.aimDirection.x,sol.prediction.aimDirection.z]])
    }
    rows.append(["name":name,"seconds":elapsed,"solutions":data])
    print("CASE \(name) count=\(solutions.count) seconds=\(elapsed)")
    if name == "obstacle" {
        check(solutions.contains { $0.rails == [.near,.right,.far] },"Allowed thin fallback remains")
    }
    if name == "screenshot-approx" {
        check(solutions.contains { $0.rails == [.right] },"Centered single-rail route remains")
        #if CENTERED_CHECK
        let serial = BankKickSolvePipeline.solveKick(cue:cue,target:target,surfaceY:y,power:power,limit:nil,parallelRefinement:false)
        check(serial.count == solutions.count,"Serial count")
        for (a,b) in zip(serial,solutions) {
            check(a.rails == b.rails && a.spinX == b.spinX && a.prediction.aimDirection.x == b.prediction.aimDirection.x && a.prediction.aimDirection.z == b.prediction.aimDirection.z,"Deterministic serial/parallel")
        }
        #endif
    }
}
let token = PredictionCancellation(); token.cancel()
check(BankKickSolvePipeline.solveKick(cue:point(0.68,0.28),target:point(-1.07,-0.27),surfaceY:y,power:2.4,cancellation:token).isEmpty,"Cancellation")
let bankCases: [(String,SCNVector3,SCNVector3,Int,Float)] = [
    ("parallel-screenshot-approx",point(0.43,-0.16),point(0.40,0.39),4,2.4),
    ("parallel-mirror-z",point(0.43,0.16),point(0.40,-0.39),5,2.4),
    ("prior-screenshot",point(0,-0.25),point(-0.28,0.22),0,2.38),
    ("typical",point(-0.5,-0.2),point(0.1,0.1),1,3.6),
    ("middle",point(-0.5,-0.2),point(0.4,0.25),4,3.6),
    ("long",point(-0.9,-0.4),point(0.6,0.3),0,4.5)
]
var bankRows: [[String:Any]] = []
var rejectedOldBanks = 0, rejectedOldKicks = 0
for (name,cue,target,pocket,power) in bankCases {
    let catalog = BankKickSolvePipeline.solveBank(cue:cue,object:target,pocketIndex:pocket,surfaceY:y,power:power,limit:nil)
    for sol in catalog {
        check(BankRouteQuality.accepts(sol.prediction),"Invalid bank")
        check(!hasParallelPair(sol.prediction,kick:false),"Parallel bank leaked")
    }
    bankRows.append(["name":name,"solutions":catalog.map { $0.rails.map { String(describing:$0) }.joined(separator:",") }])
    print("BANK \(name) count=\(catalog.count)")
    for spin: Float in [0,-0.3,0.3] {
        let input = ShotInput(cueBall:cue,targetBall:target,pocketIndex:pocket,velocity:power,spinX:spin,spinY:0,surfaceY:y)
        for (rails,prediction) in FrozenBankQualityPredictor20261102.predictBankAll(input,includePresentation:false) {
            if BankKickValidity.bank(prediction) && hasParallelPair(prediction,kick:false) {
                rejectedOldBanks += 1
                check(!BankRouteQuality.accepts(prediction),"Old real parallel bank rejected")
                check(BankKickSolvePipeline.bankSolution(input:input,seedRails:rails,prediction:prediction,measureRobustness:false)==nil,"Old bank not in catalog")
            }
        }
    }
}
for (cue,target,power) in [(point(0.68,0.28),point(-0.57,-0.19),Float(2.4)),
                            (point(-0.5,-0.2),point(0.4,0.25),Float(3.6)),
                            (point(0.70,0.28),point(-0.57,-0.19),Float(3.6))] {
    for spin: Float in [0,-0.3,0.3] {
        let input = ShotInput(cueBall:cue,targetBall:target,pocketIndex:0,velocity:power,spinX:spin,spinY:0,surfaceY:y)
        for (rails,prediction) in FrozenBankQualityPredictor20261102.predictKickAll(input,includePresentation:false) {
            if BankKickValidity.kick(prediction) && hasParallelPair(prediction,kick:true) {
                rejectedOldKicks += 1
                check(!KickRouteQuality.accepts(prediction),"Old real parallel kick rejected")
                check(BankKickSolvePipeline.kickSolution(input:input,seedRails:rails,prediction:prediction,measureRobustness:false)==nil,"Old kick not in catalog")
            }
        }
    }
}
print("OLD_PARALLEL_COUNTS bank=\(rejectedOldBanks) kick=\(rejectedOldKicks)")
check(rejectedOldBanks > 0 && rejectedOldKicks > 0,"Must reject real old parallel banks AND kicks")
check(bankRows.contains { !($0["solutions"] as! [String]).isEmpty },"Normal bank routes remain")
let payload: [String:Any] = ["cases":rows,"bankCases":bankRows,"checks":checks,"realNoPostRailRejected":rejectedRealContacts,
                           "oldParallelBanksRejected":rejectedOldBanks,"oldParallelKicksRejected":rejectedOldKicks]
try JSONSerialization.data(withJSONObject:payload,options:[.prettyPrinted,.sortedKeys]).write(to:output)
print("PASS \(checks) checks; \(rows.count) kick / \(bankRows.count) bank scenarios; old rejected bank=\(rejectedOldBanks) kick=\(rejectedOldKicks)")
