import Foundation
import SceneKit

// Research metric, not a probability: target-only pocket tolerance and a separate
// conservative obstacle mask. No current cue position enters this calculation.
struct OwnPocket: Codable {
    var pocket:Int
    var status:String
    var geometricDegrees:Double?
    var clearDegrees:Double?
    var clearIntervals:[[Double]] = [] // absolute radians, unwrapped around the clean window
}
struct OwnPotential: Codable {
    var pockets:[OwnPocket]
    var bestGeometricDegrees:Double? {pockets.compactMap(\.geometricDegrees).max()}
    var bestClearDegrees:Double? {pockets.compactMap(\.clearDegrees).filter{$0>0}.max()}
    var bestPocket:Int? {pockets.filter{($0.clearDegrees ?? 0)>0}.max{($0.clearDegrees ?? 0)<($1.clearDegrees ?? 0)}?.pocket}
    var openPocketCount:Int {pockets.filter{($0.clearDegrees ?? 0)>0}.count}
    var unavailableCount:Int {pockets.filter{$0.status=="unavailable"}.count}
    func preserves(_ before:OwnPotential)->Bool {
        guard let a=bestClearDegrees,a>0 else{return false}
        return a+1e-8 >= (before.bestClearDegrees ?? 0)
    }
    var json:[String:Any] {
        var value=(try! JSONSerialization.jsonObject(with:JSONEncoder().encode(self))) as! [String:Any]
        value["bestGeometricDegrees"]=bestGeometricDegrees.map { $0 as Any } ?? NSNull()
        value["bestClearDegrees"]=bestClearDegrees.map { $0 as Any } ?? NSNull()
        value["bestPocket"]=bestPocket.map { $0 as Any } ?? NSNull()
        value["openPocketCount"]=openPocketCount;value["unavailableCount"]=unavailableCount
        value["scope"]="target-only clean-window angle; known lower bound after infinite-ray 2R blocker cone subtraction; no cue input"
        return value
    }
}
func ownSubtractCone(_ interval:[Double],direction:Double,half:Double)->[[Double]] {
    var fragments=[interval]
    let midpoint=(interval[0]+interval[1])/2
    let centre=midpoint+atan2(sin(direction-midpoint),cos(direction-midpoint))
    for shift in [-2*Double.pi,0,2*Double.pi] {
        let a=centre+shift-half,b=centre+shift+half
        fragments=fragments.flatMap {r -> [[Double]] in
            if b<=r[0] || a>=r[1] {return [r]}
            var result=[[Double]]()
            if a>r[0] {result.append([r[0],min(a,r[1])])}
            if b<r[1] {result.append([max(b,r[0]),r[1]])}
            return result
        }
    }
    return fragments.filter{$0[1]-$0[0]>1e-12}
}
struct OwnPotentialEvaluator {
    var cache=[String:OwnPotential]()
    mutating func evaluate(_ target:SCNVector3,blocker:SCNVector3)->OwnPotential {
        let key="\(target.x.bitPattern):\(target.z.bitPattern):\(blocker.x.bitPattern):\(blocker.z.bitPattern)"
        if let existing=cache[key] {return existing}
        let x=Double(blocker.x)-Double(target.x),z=Double(blocker.z)-Double(target.z),distance=hypot(x,z)
        let diameter=2*Double(AngleSceneCalculator.ballRadius)
        var pockets=[OwnPocket]()
        for pocket in 0..<6 {
            switch PocketToleranceGeometry.evaluate(x:target.x,z:target.z,pocket:pocket,useTable:false) {
            case .unavailable: pockets.append(.init(pocket:pocket,status:"unavailable"))
            case .noStraightWindow: pockets.append(.init(pocket:pocket,status:"no-known-positive-window"))
            case .window(let w):
                let raw=AngleSceneCalculator.defenseCleanWindow(SCNVector3(target.x,0,target.z),pocketIndex:pocket,stepDegrees:0.025)
                let interval=(raw["intervals"] as! [[String:Any]])[0]
                precondition(abs((interval["widthDegrees"] as! Double)-w.degrees)<1e-8)
                let left=(raw["baseRadians"] as! Double)+(interval["leftDegrees"] as! Double)*Double.pi/180
                let right=left+w.degrees*Double.pi/180
                // Excluding the entire forward-ray cone is conservative: a blocker
                // beyond pocket capture may be unnecessarily removed, never admitted.
                let fragments=distance>diameter ? ownSubtractCone([left,right],direction:atan2(z,x),half:asin(min(1,diameter/distance))):[]
                let width=fragments.map{($0[1]-$0[0])*180/Double.pi}.max() ?? 0
                pockets.append(.init(pocket:pocket,status:width>0 ? "confirmed-positive":"blocker-cone-excluded",geometricDegrees:w.degrees,clearDegrees:width,clearIntervals:fragments))
            }
        }
        let value=OwnPotential(pockets:pockets);cache[key]=value;return value
    }
}
