import Foundation
import SceneKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let y: Float = 0.8
func point(_ x: Float, _ z: Float) -> SCNVector3 { .init(x, y + BallPhysics.radius, z) }
func impact(_ prediction: ShotPrediction) -> Float {
    guard let c = prediction.recorder?.firstBallContacts[ShotInput.cueBallName] else { return 1 }
    let d = c.other.position - c.incoming.position
    let v = c.incoming.velocity
    return min(1, abs(d.x * v.z - d.z * v.x) / (hypotf(d.x,d.z) * hypotf(v.x,v.z)))
}
var checks = 0
func check(_ ok: Bool, _ message: String) {
    checks += 1
    if !ok { fatalError(message) }
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

let cases: [(String,SCNVector3,SCNVector3,Float,[ObstacleBall])] = [
    ("screenshot-approx",point(0.68,0.28),point(-1.07,-0.27),2.4,[]),
    ("mirror-x",point(-0.68,0.28),point(1.07,-0.27),2.4,[]),
    ("mirror-z",point(0.68,-0.28),point(-1.07,0.27),2.4,[]),
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
    if name == "screenshot-approx" {
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
let payload: [String:Any] = ["cases":rows,"checks":checks]
try JSONSerialization.data(withJSONObject:payload,options:[.prettyPrinted,.sortedKeys]).write(to:output)
print("PASS \(checks) checks; \(rows.count) scenarios")
