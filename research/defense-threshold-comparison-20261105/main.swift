import Foundation
import SceneKit
let root=URL(fileURLWithPath:CommandLine.arguments[1])
let config=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("scenario.json"))) as! [String:Any]
func save(_ a:Any,_ u:URL)throws {try JSONSerialization.data(withJSONObject:a,options:[.sortedKeys,.prettyPrinted]).write(to:u,options:.atomic)}
guard let model=TableModelLoader.loadTable(includeVisual:false),let node=model.cueStickNode else{fatalError("Missing cue model")}
let profile=CueStick(modelCueStickNode:node).clearanceProfile
precondition(!profile.isEmpty)
var results=[[String:Any]]()
for item in config["cases"] as! [[String:Any]] {
    let label=item["label"] as! String,dir=root.appendingPathComponent(label)
    if !FileManager.default.fileExists(atPath:dir.appendingPathComponent("scan-adaptive.json").path) {
        var input=config;input["target"]=item["target"]
        try scan(output:dir,input:input)
    }
    let data=try JSONSerialization.jsonObject(with:Data(contentsOf:dir.appendingPathComponent("scan-adaptive.json"))) as! [String:Any]
    let map=DefenseRegionMap(scan:data,threshold:70)
    try save(map.json,dir.appendingPathComponent("blocks.json"))
    let q=try JSONDecoder().decode(DefenseBankQuestion.self,from:JSONSerialization.data(withJSONObject:item["question"]!))
    let result=try PositionPlaySolver.solveDefenseResearch(question:q,map:map,profile:profile,output:dir)
    try save(result,dir.appendingPathComponent("routes.json"))
    results.append(["label":label,"questionID":q.id,"thresholdResults":result["thresholdResults"]!,"retainedRoutes":result["retainedCount"]!,"tiers":result["tiers"]!,"seconds":result["seconds"]!])
    try save(results,root.appendingPathComponent("native-summary.json"))
    print("FINISH \(label) \(result["thresholdResults"]!) seconds=\(result["seconds"]!)");fflush(stdout)
}
precondition(results.count==9)
