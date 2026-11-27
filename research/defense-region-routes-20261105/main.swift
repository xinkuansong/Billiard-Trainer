import Foundation
import SceneKit
let root=URL(fileURLWithPath:CommandLine.arguments[1])
let config=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("scenario.json"))) as! [String:Any]
func save(_ a:Any,_ u:URL)throws {try JSONSerialization.data(withJSONObject:a,options:[.sortedKeys,.prettyPrinted]).write(to:u,options:.atomic)}
guard let model=TableModelLoader.loadTable(includeVisual:false),let node=model.cueStickNode else{fatalError("Missing cue model")}
let profile=CueStick(modelCueStickNode:node).clearanceProfile
precondition(!profile.isEmpty)
var selected=[[String:Any]](),screening=[[String:Any]]()
for item in config["cases"] as! [[String:Any]] {
    if selected.count==5 {break}
    let label=item["label"] as! String,dir=root.appendingPathComponent(label)
    try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
    print("SCAN \(label)");fflush(stdout)
    try scan(output:dir,input:item)
    let data=try JSONSerialization.jsonObject(with:Data(contentsOf:dir.appendingPathComponent("scan-adaptive.json"))) as! [String:Any]
    let rows=data["rows"] as! [[String:Any]],scores=rows.compactMap{$0["score"] as? Double}
    let maxScore=scores.max() ?? -1,map=DefenseRegionMap(scan:data,threshold:90)
    let has95=scores.contains{$0>=95}
    screening.append(["label":label,"maximum":maxScore,"has90":!map.blocks.isEmpty,"has95":has95,"blocks":map.blocks.count])
    try save(screening,root.appendingPathComponent("screening.json"))
    guard !map.blocks.isEmpty,has95 else{continue}
    try save(map.json,dir.appendingPathComponent("blocks.json"))
    let q=try JSONDecoder().decode(DefenseBankQuestion.self,from:JSONSerialization.data(withJSONObject:item["question"]!))
    let result=try PositionPlaySolver.solveDefenseResearch(question:q,map:map,profile:profile,output:dir)
    try save(result,dir.appendingPathComponent("routes.json"))
    selected.append(["label":label,"questionID":q.id,"target":item["target"]!,"maximum":maxScore,"blocks":map.blocks.count,"retainedRoutes":result["retainedCount"]!,"deduplicatedRoutes":result["deduplicatedCount"]!,"seconds":result["seconds"]!])
    try save(selected,root.appendingPathComponent("selected.json"))
    print("FINISH \(label) routes=\(result["retainedCount"]!) seconds=\(result["seconds"]!)");fflush(stdout)
}
try save(["selectedCount":selected.count,"required":5,"passes":selected.count==5,"screened":screening.count,"cases":selected],root.appendingPathComponent("native-summary.json"))
if selected.count != 5 {exit(2)}
