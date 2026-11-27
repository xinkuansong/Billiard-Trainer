import Foundation
import SceneKit
let root=URL(fileURLWithPath:CommandLine.arguments[1])
let old=root.deletingLastPathComponent().appendingPathComponent("defense-region-routes-20261105")
let config=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("scenario.json"))) as! [String:Any]
func save(_ a:Any,_ u:URL)throws {try JSONSerialization.data(withJSONObject:a,options:[.sortedKeys,.prettyPrinted]).write(to:u,options:.atomic)}
// Independent ray/disk check of circular interval subtraction, including wrap.
var rayChecks=0
for start in [-4.0,-3.15,-1.0,0.0,2.9,6.0] {for direction in [-3.14,-2.0,0,1.5,3.14] {
    let width=0.7,radius=0.12,half=asin(radius)
    let intervals=ownSubtractCone([start,start+width],direction:direction,half:half)
    for i in 0...2000 {
        let a=start+width*Double(i)/2000
        let projection=cos(a-direction),distance=projection>0 ? abs(sin(a-direction)):1
        let blocked=distance<radius
        let kept=intervals.contains{a>$0[0]+1e-10 && a<$0[1]-1e-10}
        if a>start+1e-10 && a<start+width-1e-10 && abs(distance-radius)>1e-10 {precondition(kept != blocked)}
        rayChecks+=1
    }
}}
try save(["passed":true,"rayDiskComparisons":rayChecks,"metricHasNoCueInput":true],root.appendingPathComponent("geometry-checks.json"))
guard let model=TableModelLoader.loadTable(includeVisual:false),let node=model.cueStickNode else{fatalError("Missing cue model")}
let profile=CueStick(modelCueStickNode:node).clearanceProfile
precondition(!profile.isEmpty)
var selected=[[String:Any]]()
for item in (config["cases"] as! [[String:Any]]).prefix(5) {
    let label=item["label"] as! String,dir=root.appendingPathComponent(label)
    let data=try JSONSerialization.jsonObject(with:Data(contentsOf:dir.appendingPathComponent("scan-adaptive.json"))) as! [String:Any]
    let map=DefenseRegionMap(scan:data,threshold:90)
    let q=try JSONDecoder().decode(DefenseBankQuestion.self,from:JSONSerialization.data(withJSONObject:item["question"]!))
    func v(_ point:[Double])->SCNVector3 {SCNVector3(Float(point[0]),BTTablePhysics.surfaceY+BallPhysics.radius,Float(point[1]))}
    let opponent=v(q.balls.first{$0.number==9}!.position),own=v(q.balls.first{$0.number==8}!.position)
    var evaluator=OwnPotentialEvaluator()
    let baseline=evaluator.evaluate(own,blocker:opponent)
    let previous=try JSONSerialization.jsonObject(with:Data(contentsOf:old.appendingPathComponent(label).appendingPathComponent("routes.json"))) as! [String:Any]
    var oldMetrics=[[String:Any]]()
    for route in previous["routes"] as! [[String:Any]] {
        let final=route["finalPositions"] as! [String:[Double]],value=evaluator.evaluate(v(final["_8"]!),blocker:opponent)
        oldMetrics.append(["id":route["id"]!,"shot":route["shot"]!,"finalPositions":final,"defenseScore":(route["effect"] as! [String:Any])["score"]!,"before":baseline.json,"after":value.json,"ownPreserved":value.preserves(baseline),"oldDefenseProbePasses":route["probePasses"]!])
    }
    try save(oldMetrics,dir.appendingPathComponent("old-route-metrics.json"))
    print("BASELINE \(label) own=\(baseline.bestClearDegrees ?? -1) oldPreserve=\(oldMetrics.filter{$0["ownPreserved"] as! Bool}.count)");fflush(stdout)
    let result=try PositionPlaySolver.solveDefenseResearch(question:q,map:map,profile:profile,output:dir)
    try save(result,dir.appendingPathComponent("routes.json"))
    selected.append(["label":label,"questionID":q.id,"retainedRoutes":result["retainedCount"]!,"stableJointCandidates":result["stableJointCandidates"]!,"tiers":result["tiers"]!,"seconds":result["seconds"]!])
    try save(selected,root.appendingPathComponent("selected.json"))
    print("FINISH \(label) routes=\(result["retainedCount"]!) seconds=\(result["seconds"]!)");fflush(stdout)
}
try save(["selectedCount":selected.count,"required":5,"passes":selected.count==5,"cases":selected],root.appendingPathComponent("native-summary.json"))
precondition(selected.count==5)
