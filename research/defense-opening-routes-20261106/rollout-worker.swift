import Foundation
import SceneKit
let root=URL(fileURLWithPath:CommandLine.arguments[1])
let fm=FileManager.default
func save(_ a:Any,_ u:URL)throws{try JSONSerialization.data(withJSONObject:a,options:[.sortedKeys]).write(to:u,options:.atomic)}
let questions=try JSONDecoder().decode([DefenseBankQuestion].self,from:Data(contentsOf:root.appendingPathComponent("inputs.json")))
let identity=try String(contentsOf:root.appendingPathComponent("identity.txt")).trimmingCharacters(in:.whitespacesAndNewlines)
let directory=root.appendingPathComponent("cases");try fm.createDirectory(at:directory,withIntermediateDirectories:true)
guard let model=TableModelLoader.loadTable(includeVisual:false),let node=model.cueStickNode else{fatalError("Missing cue model")}
let profile=CueStick(modelCueStickNode:node).clearanceProfile;precondition(!profile.isEmpty)
for q in questions {
    // q.id is controlled immutable bank input; filesystem-safe names checked by controller.
    let dest=directory.appendingPathComponent(q.id);try fm.createDirectory(at:dest,withIntermediateDirectories:true)
    if fm.fileExists(atPath:dest.appendingPathComponent("complete.json").path){continue}
    try autoreleasepool {
        let start=ProcessInfo.processInfo.systemUptime
        var result=try PositionPlaySolver.solveDefenseResearch(question:q,map:DefenseRegionMap(),profile:profile,output:dest,rolloutFirstPass:true)
        let fastSeconds=ProcessInfo.processInfo.systemUptime-start
        let fastCount=result["retainedCount"] as! Int
        var scan:[String:Any]=["deferred":true,"radius":Double(AngleSceneCalculator.ballRadius)]
        let quickOnly = root.deletingLastPathComponent().lastPathComponent.hasPrefix("quick-")
        result["quickOnly"] = quickOnly
        if fastCount < 2 && !quickOnly {
            scan=try defenseScan(q)
            let map=DefenseRegionMap(scan:scan,threshold:75)
            let fastRoutes=result["routes"] as! [[String:Any]]
            result=try PositionPlaySolver.solveDefenseResearch(question:q,map:map,profile:profile,output:dest)
            var routes=result["routes"] as! [[String:Any]]
            for var extra in fastRoutes where routes.count < 6 {
                let seq=extra["railSequences"] as! [String:[Int]]
                guard !routes.contains(where:{ $0["railSequences"] as! [String:[Int]] == seq }) else {continue}
                extra["id"]=routes.count+1
                extra["regionDeferredAtSearch"]=true
                routes.append(extra)
            }
            result["routes"]=routes;result["retainedCount"]=routes.count;result["admitted"]=routes.count>=2
        }
        result["fastSearchSeconds"]=fastSeconds;result["fastVerifiedRoutes"]=fastCount
        try save(["question":try defenseEncode(q),"identity":identity,"scan":scan,"result":result,"wallSeconds":ProcessInfo.processInfo.systemUptime-start],dest.appendingPathComponent("result.json"))
        try save(["id":q.id,"identity":identity,"retained":result["retainedCount"]!,"seconds":ProcessInfo.processInfo.systemUptime-start],dest.appendingPathComponent("complete.json"))
        print("FINISH \(q.id) routes=\(result["retainedCount"]!) seconds=\(ProcessInfo.processInfo.systemUptime-start)");fflush(stdout)
    }
}
