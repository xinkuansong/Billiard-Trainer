import Foundation
import SceneKit

// Static terminal-state research only. No ShotPrediction, fictitious events or shot solving.
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let input = try JSONSerialization.jsonObject(with: Data(contentsOf: output.appendingPathComponent("scenario.json"))) as! [String:Any]
let targetInput = input["target"] as! [Double]
typealias P = DefenseAttackAssessment.P
func point(_ v:SCNVector3)->P { P(Double(v.x),Double(v.z)) }
func object<T:Encodable>(_ value:T)throws->Any {try JSONSerialization.jsonObject(with:JSONEncoder().encode(value))}
func write(_ value:Any,_ name:String)throws {
    try JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent(name),options:.atomic)
}
let geometry = DefenseAttackAssessment()
func valid(_ p:P, target:P)->Bool {
    let r=geometry.rad
    guard abs(p.x)<=geometry.hx-r,abs(p.z)<=geometry.hz-r,(p-target).length>=2*r+0.00001 else {return false}
    guard !geometry.table.pockets.contains(where:{$0.containsCapture(p.scn)}) else {return false}
    for line in geometry.table.linearCushions {
        if geometry.dist(p,point(line.start),point(line.end)) < r {return false}
    }
    for arc in geometry.table.circularCushions {
        let centre=point(arc.center),radius=Double(arc.radius)
        let angle=atan2(p.z-centre.z,p.x-centre.x)
        var distance=min((p-(centre+P(cos(Double(arc.startAngle)),sin(Double(arc.startAngle)))*radius)).length,
                         (p-(centre+P(cos(Double(arc.endAngle)),sin(Double(arc.endAngle)))*radius)).length)
        // The production arc test has an angular allowance; conservative at endpoints.
        if arc.isAngleInRange(Float(angle)) {distance=min(distance,abs((p-centre).length-radius))}
        if distance<r {return false}
    }
    return true
}
func status(_ e:DefenseEffect)->String {
    if e.fullDirectBlock {return "direct-block"}
    if e.potContactsBlocked == true {return "pot-block"}
    if e.estimateReason != nil {return e.pipeRoute == nil ? "bound-estimate":"route-estimate"}
    if e.pipeRoute?.zeroWidthEstimate == true {return "zero-width"}
    return "formula"
}
// Coarse cells cover the same conservative centre domain as the earlier scan.
// Cell colours are sampled values, never certified continuous bounds.
struct Cell {
    let x0,z0,x1,z1:Double
    let ix,iz,level:Int
    var centre:P {P((x0+x1)/2,(z0+z1)/2)}
    var json:[Double] {[x0,z0,x1,z1]}
}
struct Sample {
    let cell:Cell
    let effect:DefenseEffect?
    var state:String {effect.map(status) ?? "invalid-placement"}
    var json:[String:Any] {
        get throws {
            var r:[String:Any] = ["bounds":cell.json,"x":cell.centre.x,"z":cell.centre.z,
                "ix":cell.ix,"iz":cell.iz,"level":cell.level,"status":state]
            if let e=effect {r["score"]=e.score!;r["effect"]=try object(e)}
            return r
        }
    }
}
var issues=[String](),windowSeconds=0.0,scoringSeconds=0.0,validCount=0
let start=ProcessInfo.processInfo.systemUptime
let target=point(P(targetInput).scn)
var windows=DefenseAttackAssessment()
let windowStart=ProcessInfo.processInfo.systemUptime
let w=(0..<6).map {windows.window(target,$0)}
windowSeconds=ProcessInfo.processInfo.systemUptime-windowStart
try write(w,"windows-base.json")
func evaluate(_ cell:Cell)throws->Sample {
    let c=point(cell.centre.scn)
    guard valid(c,target:target) else {return Sample(cell:cell,effect:nil)}
    let begin=ProcessInfo.processInfo.systemUptime
    let e=try DefenseEffect.regionState(cue:c.scn,target:target.scn,blockers:[],windows:windows)
    scoringSeconds += ProcessInfo.processInfo.systemUptime-begin
    guard let score=e.score,score.isFinite,(0...100).contains(score),e.unavailableReason==nil else {
        throw NSError(domain:"Invalid region score",code:1)
    }
    validCount += 1
    return Sample(cell:cell,effect:e)
}
let coarseStep=input["gridStepMeters"] as! Double
let fineStep=input["refinementStepMeters"] as! Double
let scoreChange=input["refinementScoreChange"] as! Double
precondition(coarseStep>fineStep && fineStep>0 && scoreChange>0)
let hx=geometry.hx-geometry.rad,hz=geometry.hz-geometry.rad
let nx=Int(ceil(2*hx/coarseStep)),nz=Int(ceil(2*hz/coarseStep))
let dx=2*hx/Double(nx),dz=2*hz/Double(nz)
var coarse=[Sample]()
for iz in 0..<nz {
    for ix in 0..<nx {
        let cell=Cell(x0:-hx+Double(ix)*dx,z0:-hz+Double(iz)*dz,
                      x1:-hx+Double(ix+1)*dx,z1:-hz+Double(iz+1)*dz,ix:ix,iz:iz,level:0)
        coarse.append(try evaluate(cell))
    }
}
var marked=[Int:Set<String>]()
func mark(_ index:Int,_ reason:String) {marked[index,default:[]].insert(reason)}
for (i,a) in coarse.enumerated() {
    // Rail-adjacent strips warrant refinement because cue comfort depends on clearance.
    if a.cell.ix==0 || a.cell.ix==nx-1 || a.cell.iz==0 || a.cell.iz==nz-1 {mark(i,"rail-edge")}
    for oz in -1...1 {
        for ox in -1...1 where ox != 0 || oz != 0 {
            let ix=a.cell.ix+ox,iz=a.cell.iz+oz
            guard (0..<nx).contains(ix),(0..<nz).contains(iz) else {continue}
            let j=iz*nx+ix,b=coarse[j]
            if a.state != b.state {mark(i,"classification-boundary");mark(j,"classification-boundary")}
            if let av=a.effect?.score,let bv=b.effect?.score,abs(av-bv)>=scoreChange {
                mark(i,"score-change");mark(j,"score-change")
            }
        }
    }
}
var fine=[Sample](),leaves=[Sample]()
for (i,s) in coarse.enumerated() {
    guard marked[i] != nil else {leaves.append(s);continue}
    let c=s.cell,fx=Int(ceil((c.x1-c.x0)/fineStep)),fz=Int(ceil((c.z1-c.z0)/fineStep))
    for iz in 0..<fz {
        for ix in 0..<fx {
            let sub=Cell(x0:c.x0+(c.x1-c.x0)*Double(ix)/Double(fx),
                         z0:c.z0+(c.z1-c.z0)*Double(iz)/Double(fz),
                         x1:c.x0+(c.x1-c.x0)*Double(ix+1)/Double(fx),
                         z1:c.z0+(c.z1-c.z0)*Double(iz+1)/Double(fz),ix:c.ix,iz:c.iz,level:1)
            let r=try evaluate(sub);fine.append(r);leaves.append(r)
        }
    }
}
let measuredCoreSeconds=windowSeconds+scoringSeconds
let area=leaves.reduce(0.0) {$0+($1.cell.x1-$1.cell.x0)*($1.cell.z1-$1.cell.z0)}
if abs(area-4*hx*hz)>1e-10 {issues.append("Adaptive leaves do not cover the input rectangle")}
if fine.contains(where: {max($0.cell.x1-$0.cell.x0,$0.cell.z1-$0.cell.z0)>fineStep+1e-9}) {
    issues.append("Refined leaf exceeds requested maximum size")
}
try write(["target":target.json,"coarseMaximumStep":coarseStep,"fineMaximumStep":fineStep,
           "scoreChangeTrigger":scoreChange,"nx":nx,"nz":nz,"dx":dx,"dz":dz,
           "coarse":try coarse.map {try $0.json},"rows":try leaves.map {try $0.json},
           "refinedRoots":marked.keys.sorted().map {["index":$0,"reasons":marked[$0]!.sorted()] as [String:Any]}],"scan-adaptive.json")
try write(["radius":geometry.rad,"halfX":geometry.hx,"halfZ":geometry.hz,
           "rails":geometry.mainRails.map{[$0.0.json,$0.1.json]},
           "pockets":geometry.table.pockets.map{["center":point($0.center).json,"radius":Double($0.radius)] as [String:Any]}],"geometry.json")
let elapsed=ProcessInfo.processInfo.systemUptime-start
try write(["scoringVersion":DefenseEffect.version,"issues":issues,"passed":issues.isEmpty,
           "cacheParityCount":0,"targetPerturbationCount":0,"coarseCount":coarse.count,
           "refinedRootCount":marked.count,"additionalFineCount":fine.count,"leafCount":leaves.count,
           "totalSampleCount":coarse.count+fine.count,"validEvaluationCount":validCount,
           "windowSeconds":windowSeconds,"scoringSeconds":scoringSeconds,
           "coreSeconds":measuredCoreSeconds,"seconds":elapsed],"native-results.json")
print("DONE coarse=\(coarse.count), fine=\(fine.count), core=\(measuredCoreSeconds)s, total=\(elapsed)s, issues=\(issues)")
if !issues.isEmpty {exit(2)}
