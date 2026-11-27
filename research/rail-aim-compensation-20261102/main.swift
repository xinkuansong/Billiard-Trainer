import Foundation
import SceneKit

let bankURL = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let bank = try TrainingGridBank(data: Data(contentsOf: bankURL), fingerprint: "diagnostic")
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
func point(_ p: SCNVector3) -> [Float] { [p.x, p.z] }
func outcome(_ p: ShotPrediction, _ pocket: Int) -> String {
    AccuracyShotJudgement.evaluate(p, pocketIndex: pocket).rawValue
}
func facts(_ p: ShotPrediction, _ pocket: Int, trace: Bool = false) -> [String: Any] {
    var d: [String: Any] = ["outcome": outcome(p,pocket), "termination": String(describing:p.termination),
        "feasible":p.feasible, "scratch":p.cuePocketed, "aim":point(p.strikeDirection ?? p.aimDirection),
        "pipe":point(p.pocketAimPoint), "cut":p.cutAngleDeg,
        "events":p.events.map { e -> [String:Any] in
            var q: [String:Any] = ["t":e.time,"kind":String(describing:e.kind)]
            if let c=e.cushionIndex { q["cushion"]=c }; return q
        }]
    if let frames=p.recorder?.framesByBallName[ShotInput.targetBallName] {
        if let f=frames.first(where: { hypotf($0.velocity.x,$0.velocity.z)>0.001 }) {
            d["postVelocity"]=[f.velocity.x,f.velocity.z]
            d["postSpin"]=[f.angularVelocity.x,f.angularVelocity.y,f.angularVelocity.z]
        }
        if trace { d["frames"]=frames.map { ["t":$0.time,"p":point($0.position),"v":point($0.velocity)] as [String:Any] } }
    }
    return d
}
func emit(_ row: [String:Any], to url:URL) throws {
    var data=try JSONSerialization.data(withJSONObject:row,options:[.sortedKeys]);data.append(10)
    if !FileManager.default.fileExists(atPath:url.path) { FileManager.default.createFile(atPath:url.path,contents:nil) }
    let f=try FileHandle(forWritingTo:url);try f.seekToEnd();try f.write(contentsOf:data);try f.close()
}
var samples:[TrainingBankBoard]=[]
for angle in 0..<5 { for pocket in 0..<2 { for rail in 0..<3 {
    let codes=bank.payload.combinationTable.indices.filter { let c=bank.payload.combinationTable[$0];return c.angleIndex==angle && c.pocketType==pocket && c.railIndex==rail && !bank.pools[$0].isEmpty }
    for repetition in 0..<2 where !codes.isEmpty {
        let code=codes[(codes.count/2+repetition*3)%codes.count], pool=bank.pools[code]
        let ref=pool[(pool.count/3+repetition*137)%pool.count]
        samples.append(bank.board(reference:ref,combination:code))
    }
}}}
try encoder.encode(samples).write(to:output.appendingPathComponent("boards.json"))
let speeds:[Float]=[1,1.5,2,2.5,3,4,6]
let parameters:[(Float,Float,Float)]=speeds.map { ($0,0,0) } + [Float(2),Float(3)].flatMap { v in [Float(-0.5),-0.25,0.25,0.5].map { (v,$0,Float(0)) } }
var rescued=0, scans=0
for (index,b) in samples.enumerated() {
    for (v,sx,sy) in parameters {
        try autoreleasepool {
            let input=ShotInput(cueBall:b.cue.vector,targetBall:b.target.vector,pocketIndex:b.pocketIndex,velocity:v,spinX:sx,spinY:sy,surfaceY:0)
            let prediction=ShotPredictor.predict(input,maxEvents:2000,maxTime:45)
            var row:[String:Any]=["board":b.id,"index":index,"combination":b.combinationID!,"pocket":b.pocketIndex,
                "gap":SceneTrainingRailGeometry.clearance(b.target.vector),"speed":v,"spinX":sx,"spinY":sy,
                "baseline":facts(prediction,b.pocketIndex),"pipeKind":AngleSceneCalculator.videoPipeCandidateKind(targetBall:b.target.vector,aimPoint:prediction.pocketAimPoint,pocketIndex:b.pocketIndex,surfaceY:0)]
            // Independent complete-trajectory probes at exactly the same power/spin.
            // Keep every outcome, including misses, indirect routes and incomplete simulations.
            if prediction.feasible && !prediction.simObjectPotted && (v==2 || v==3) {
                let base=prediction.strikeDirection ?? prediction.aimDirection
                var trials:[[String:Any]]=[]
                for step in -40...40 where step != 0 {
                    let delta=Float(step)*0.025
                    let dir=base.rotatedY(delta * .pi/180)
                    let p=ShotPredictor.simulateFree(cueBall:b.cue.vector,aimDir:dir,velocity:v,spinX:sx,spinY:sy,surfaceY:0,
                        balls:[.init(name:ShotInput.targetBallName,position:b.target.vector)],maxEvents:2000,maxTime:45,
                        includePresentation:false,recordedStrikeDirection:dir)
                    trials.append(["delta":delta,"outcome":outcome(p,b.pocketIndex),"termination":String(describing:p.termination)])
                    if outcome(p,b.pocketIndex)=="success" {
                        row["rescue"]=["delta":delta,"prediction":facts(p,b.pocketIndex,trace:true)]
                        row["baseline"]=facts(prediction,b.pocketIndex,trace:true)
                        rescued+=1;break
                    }
                }
                row["scan"]=trials;scans+=1
            }
            try emit(row,to:output.appendingPathComponent("results.jsonl"))
        }
    }
    print("BOARD \(index+1)/\(samples.count) rescue=\(rescued) scanned=\(scans)");fflush(stdout)
}
print("COMPLETE boards=\(samples.count) cases=\(samples.count*parameters.count) rescue=\(rescued) scans=\(scans)")
