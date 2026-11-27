import Foundation
import SceneKit

let bankURL = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])

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
let samples=try JSONDecoder().decode([TrainingBankBoard].self,from:Data(contentsOf:output.appendingPathComponent("boards.json")))
let speeds:[Float]=[1,1.5,2,2.5,3,4,6]
let parameters:[(Float,Float,Float)]=speeds.map { ($0,0,0) } + [Float(2),Float(3)].flatMap { v in [Float(-0.5),-0.25,0.25,0.5].map { (v,$0,Float(0)) } }
// Diagnostic only: identical three-level grid, with the existing atan2 score.
func atanGrid(_ input:ShotInput)->ShotPrediction {
    var result=ShotPrediction()
    guard let ctx=ShotPredictor.prepareAim(input,into:&result) else {return result}
    let deg=Float.pi/180
    func best(_ center:Float,_ half:Float,_ step:Float)->Float {
        var bo=center,bs=Float.greatestFiniteMagnitude,o=center-half
        while o<=center+half+1e-6 {
            let s=ShotPredictor.positionAimScore(input:input,context:ctx,offset:o)
            if s<bs {bs=s;bo=o};o+=step
        };return bo
    }
    let c=best(0,12*deg,0.5*deg),m=best(c,0.6*deg,0.1*deg),f=best(m,0.12*deg,0.02*deg)
    return ShotPredictor.buildPrediction(finalAim:ctx.aimDir.rotatedY(f),context:ctx,input:input,result:result,maxEvents:2000,maxTime:45,includePresentation:false)
}
for (index,b) in samples.enumerated() {
    for (v,sx,sy) in parameters {
        try autoreleasepool {
            let input=ShotInput(cueBall:b.cue.vector,targetBall:b.target.vector,pocketIndex:b.pocketIndex,velocity:v,spinX:sx,spinY:sy,surfaceY:0)
            let p=ShotPredictor.predictForPositionSolve(input,maxEvents:2000,maxTime:45,includePresentation:true)
            let a=atanGrid(input)
            var row:[String:Any]=["index":index,"board":b.id,"speed":v,"spinX":sx,"spinY":sy,
                "position":facts(p,b.pocketIndex,trace:index==4 || index==5 || index==9),
                "atanGrid":facts(a,b.pocketIndex)]
            if b.combinationID!.hasSuffix("r2") && !p.simObjectPotted && (v==2 || v==3) && abs(sx)<=0.25 {
                let base=p.strikeDirection ?? p.aimDirection
                var trials:[[String:Any]]=[]
                for step in 1...80 {
                    for sign:Float in [-1,1] {
                        let delta=sign*Float(step)*0.0025,dir=base.rotatedY(delta * .pi/180)
                        let q=ShotPredictor.simulateFree(cueBall:b.cue.vector,aimDir:dir,velocity:v,spinX:sx,spinY:sy,surfaceY:0,
                            balls:[.init(name:ShotInput.targetBallName,position:b.target.vector)],maxEvents:2000,maxTime:45,
                            includePresentation:false,recordedStrikeDirection:dir)
                        trials.append(["delta":delta,"outcome":outcome(q,b.pocketIndex),"termination":String(describing:q.termination)])
                        if outcome(q,b.pocketIndex)=="success" && row["fineRescue"]==nil {
                            row["fineRescue"]=["delta":delta,"prediction":facts(q,b.pocketIndex,trace:true)]
                        }
                    }
                }
                row["fineScan"]=trials
            }
            try emit(row,to:output.appendingPathComponent("followup.jsonl"))
        }
    }
    print("FOLLOWUP \(index+1)/\(samples.count)");fflush(stdout)
}
print("COMPLETE followup=\(samples.count*parameters.count)")
