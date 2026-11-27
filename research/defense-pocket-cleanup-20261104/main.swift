import Foundation

// Harness supplies only the production calculator's three constants; scoring
// itself is compiled unchanged from ShotComfortScore.swift. XZ metres, Y up.
enum AngleSceneCalculator {
    static let innerLength: Float = 2.54
    static let innerWidth: Float = 1.27
    static let ballRadius: Float = 0.028575
}
struct Pocket: Decodable { let center: [Double] }
struct Geometry: Decodable { let length, width, radius: Double; let pockets: [Pocket] }
struct Option: Decodable { let pocket: Int; let cueWidth, objectWidth: Double; let aim: [Double]?; let score: Double? }
struct Row: Decodable { let key: String; let cue: [Double]; let positions: [[Double]]; let own, selectedPocket: Int; let options: [Option] }
struct Input: Decodable { let geometry: Geometry; let rows: [Row] }
struct Witness: Codable { let pocket: Int; let comfort, cut: Double; let ghost, aim: [Double] }
struct Decision: Codable { let key: String; let remove: Bool; let witnesses: [Witness] }
func distance(_ p:[Double],_ a:[Double],_ b:[Double])->Double {
    let vx=b[0]-a[0],vz=b[1]-a[1],n=vx*vx+vz*vz
    precondition(n>0)
    let t=max(0,min(1,((p[0]-a[0])*vx+(p[1]-a[1])*vz)/n))
    return hypot(p[0]-a[0]-t*vx,p[1]-a[1]-t*vz)
}
let out=CommandLine.arguments[1]
let input=try JSONDecoder().decode(Input.self,from:Data(contentsOf:URL(fileURLWithPath:out+"/input.json")))
let g=input.geometry
precondition(g.length==Double(AngleSceneCalculator.innerLength) && g.width==Double(AngleSceneCalculator.innerWidth) && g.radius==Double(AngleSceneCalculator.ballRadius))
let geometry=ShotComfortScore.Geometry(length:g.length,width:g.width,radius:g.radius)
var results=[Decision](),controls=0,maxDifference=0.0
for q in input.rows {
    let ball=q.positions[q.own],cue=q.cue
    // Replay stored representative scores before applying an additional guard.
    for o in q.options {
        if let aim=o.aim,let expected=o.score {
            let score=ShotComfortScore.evaluate(cue:(cue[0],cue[1]),ball:(ball[0],ball[1]),aim:(aim[0],aim[1]),geometry:geometry)!
            maxDifference=max(maxDifference,abs(expected-score.total));controls+=1
        }
    }
    var witnesses=[Witness]()
    let selectedAim=g.pockets[q.selectedPocket].center
    let selectedDistance=hypot(selectedAim[0]-ball[0],selectedAim[1]-ball[1])
    let snx=(selectedAim[0]-ball[0])/selectedDistance,snz=(selectedAim[1]-ball[1])/selectedDistance
    let svx=ball[0]-2*g.radius*snx-cue[0],svz=ball[1]-2*g.radius*snz-cue[1]
    let selectedCut=atan2(abs(svx*snz-svz*snx),svx*snx+svz*snz)*180/Double.pi
    let existingComfort=q.options.compactMap{$0.score}.max()!
    // This guard addresses the user-rejected missed CORNER-pocket family.
    // A middle pocket with no clean window is not reclassified as available.
    for p in 0..<4 where p != q.selectedPocket && q.options[p].cueWidth==0 {
        precondition(q.options[p].pocket==p)
        let aim=g.pockets[p].center,d=hypot(aim[0]-ball[0],aim[1]-ball[1])
        let nx=(aim[0]-ball[0])/d,nz=(aim[1]-ball[1])/d
        let ghost=[ball[0]-2*g.radius*nx,ball[1]-2*g.radius*nz]
        guard abs(ghost[0])<=g.length/2-g.radius,abs(ghost[1])<=g.width/2-g.radius else {continue}
        let others=q.positions.enumerated().filter{$0.offset != q.own}.map{$0.element}
        guard !others.contains(where:{distance($0,cue,ghost)<2*g.radius || distance($0,ball,aim)<2*g.radius}) else {continue}
        guard let score=ShotComfortScore.evaluate(cue:(cue[0],cue[1]),ball:(ball[0],ball[1]),aim:(aim[0],aim[1]),geometry:geometry),score.total>existingComfort else {continue}
        let vx=ghost[0]-cue[0],vz=ghost[1]-cue[1]
        let cut=atan2(abs(vx*nz-vz*nx),vx*nx+vz*nz)*180/Double.pi
        guard cut<selectedCut,d<selectedDistance else {continue}
        witnesses.append(Witness(pocket:p,comfort:score.total,cut:cut,ghost:ghost,aim:aim))
    }
    results.append(Decision(key:q.key,remove:!witnesses.isEmpty,witnesses:witnesses))
}
precondition(maxDifference<1e-8,"Stored score regression")
let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
try encoder.encode(results).write(to:URL(fileURLWithPath:out+"/decisions.json"))
try JSONSerialization.data(withJSONObject:["passed":true,"evaluations":results.count,"storedScoreControls":controls,"maximumScoreDifference":maxDifference,"removedTargets":results.filter{$0.remove}.count],options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:out+"/score-audit.json"))
print("Targets",results.count,"removed",results.filter{$0.remove}.count,"score controls",controls,"max difference",maxDifference)
