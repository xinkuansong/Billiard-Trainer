// A finer search for previously unresolved positive windows. The geometry proposes an angle;
// only a complete replay at normal player inputs can admit an improvement.
import Foundation
import SceneKit
@testable import QiuJi

@main
struct Refinement {
    struct Mark: Codable {
        let key, state: String
        var input: SeparationInput?
        var dir: [Float]?
    }
    static let target = ShotInput.targetBallName
    static let y = BTTablePhysics.surfaceY
    static let profile = AccuracyTipSelector.renderedProfile()
    static func clean(_ p: ShotPrediction) -> Bool {
        ShotPredictor.bankPocketContactCount(events: p.events) == 0
    }

    static func outgoing(_ p: ShotPrediction, segments: [Int]) -> BallFrame? {
        var count = 0
        for event in p.events {
            guard case let .ballCushion(ball) = event.kind, ball == target else { continue }
            guard event.cushionIndex == segments[count] else { return nil }
            count += 1
            if count == segments.count {
                return p.recorder?.framesByBallName[target]?.last { abs($0.time-event.time)<0.00001 }
            }
        }
        return nil
    }

    static func bank(_ s: BankPracticeBankQuestion) throws -> Mark? {
        let q = BankQuestion(id: UUID(), source: s)
        let heading = atan2(Double(s.direction.z), Double(s.direction.x))
        func shot(_ speed: Float, _ degrees: Double) throws -> (SeparationInput, SCNVector3, ShotPrediction) {
            let a = heading + degrees * .pi/180
            let d = SCNVector3(Float(cos(a)),0,Float(sin(a)))
            var n = s.input
            n.velocity = speed
            return (n,d,try BankQuestionPreparer.solve(question:q,input:n,direction:d,surfaceY:y,profile:profile))
        }
        let base = try shot(s.input.velocity,0).2
        guard !clean(base), let entry = outgoing(base,segments:s.railSegments) else { return nil }
        let window = AngleSceneCalculator.defenseCleanWindow(entry.position,pocketIndex:s.pocket,stepDegrees:0.025)
        let intervals = window["intervals"] as? [[String:Any]] ?? []
        for interval in intervals {
            guard let end = interval["midEnd"] as? [Double], end.count == 2 else { continue }
            func residual(_ p: ShotPrediction) -> Double? {
                guard let f = outgoing(p,segments:s.railSegments) else { return nil }
                let dx = end[0]-Double(f.position.x), dz = end[1]-Double(f.position.z)
                let angle = atan2(Double(f.velocity.z),Double(f.velocity.x)) - atan2(dz,dx)
                return atan2(sin(angle),cos(angle))*180 / .pi
            }
            for dv: Float in [0,0.025,-0.025,0.05,-0.05,0.075,-0.075,0.1,-0.1,0.15,-0.15,0.2,-0.2] {
                let speed = s.input.velocity+dv
                guard ShotTuning.velocityRange.contains(Double(speed)) else { continue }
                func attempt(_ offset: Double) -> (Double?,Mark?) {
                    guard let (n,d,p) = try? shot(speed,offset) else { return (nil,nil) }
                    if clean(p), BankJudgement.evaluate(p,question:s,surfaceY:y).failures.isEmpty {
                        return (nil, Mark(key:s.id,state:"adjusted",input:n,dir:[d.x,d.z]))
                    }
                    return (residual(p),nil)
                }
                for probe in [0.015,-0.015,0.09,-0.09] {
                    var x = 0.0, x1 = probe
                    let first = attempt(x)
                    if let result = first.1 { return result }
                    guard var y0 = first.0 else { continue }
                    for _ in 0..<5 {
                        let next = attempt(x1)
                        if let mark = next.1 { return mark }
                        guard let y1 = next.0, abs(y1-y0)>0.00001 else { break }
                        let x2 = max(-0.7,min(0.7, x1-y1*(x1-x)/(y1-y0)))
                        if abs(x2-x1)<0.00005 { break }
                        (x,x1,y0) = (x1,x2,y1)
                    }
                }
            }
        }
        return nil
    }
    static func kball(_ l: KBallBankLayout, _ q: KBallBankQuestion, pocket: Int) -> Mark? {
        let base = SeparationInput(spinX:Float(q.sx),spinY:Float(q.sy),velocity:Float(q.v))
        for delta: Float in [0.005,0.015,0.03,0.06,0.1,0.15] {
            for (dx,dy) in [(1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)] {
                for dv: Float in [0,0.01,-0.01,0.04,-0.04,0.1,-0.1,0.2,-0.2] {
                    let n = SeparationInput(spinX:base.spinX+Float(dx)*delta,spinY:base.spinY+Float(dy)*delta,
                                            velocity:base.velocity+dv)
                    guard n.isValid, (0.6...4.5).contains(n.velocity),
                          n.spinX*n.spinX+n.spinY*n.spinY<=0.25,
                          let p = try? KBallQuestionPreparer.solve(layout:l,question:q,input:n,surfaceY:y,profile:profile),
                          clean(p), let d=p.strikeDirection,
                          KBallJudgement.failure(p,pocket:pocket,question:q,requiresReferenceTiming:true)==nil else { continue }
                    return Mark(key:q.id,state:"adjusted",input:n,dir:[d.x,d.z])
                }
            }
        }
        return nil
    }

    static func main() throws {
        let folder=URL(fileURLWithPath:CommandLine.arguments[1])
        let family=CommandLine.arguments[2]
        let pending = try JSONDecoder().decode(Set<String>.self,from:Data(contentsOf:folder.appendingPathComponent(family+"-refine-ids.json")))
        var rows=[Mark]()
        func check(_ id:String,_ operation:() throws->Mark?) throws {
            guard pending.contains(id) else{return}
            rows.append(try autoreleasepool(invoking:operation) ?? Mark(key:id,state:"searchReview"))
        }
        if family=="bank" {
            for q in try BankPracticeBankStore.load().questions { try check(q.id){try bank(q)} }
        } else {
            let store=try KBallBankStore.load()
            for entry in store.index.layouts {
                let l=try store.layout(entry)
                for q in l.questions {try check(q.id){kball(l,q,pocket:l.board.pocket)}}
            }
        }
        guard Set(rows.map(\.key))==pending else {throw NSError(domain:"Missing refinement IDs",code:1)}
        try JSONEncoder().encode(rows).write(to:folder.appendingPathComponent(family+"-refined.json"),options:.atomic)
    }
}
