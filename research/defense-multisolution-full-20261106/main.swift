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
        let scan=try defenseScan(q)
        let map=DefenseRegionMap(scan:scan,threshold:75)
        let result=try PositionPlaySolver.solveDefenseResearch(question:q,map:map,profile:profile,output:dest)
        try save(["question":try defenseEncode(q),"identity":identity,"scan":scan,"result":result,"wallSeconds":ProcessInfo.processInfo.systemUptime-start],dest.appendingPathComponent("result.json"))
        try save(["id":q.id,"identity":identity,"retained":result["retainedCount"]!,"seconds":ProcessInfo.processInfo.systemUptime-start],dest.appendingPathComponent("complete.json"))
        print("FINISH \(q.id) routes=\(result["retainedCount"]!) seconds=\(ProcessInfo.processInfo.systemUptime-start)");fflush(stdout)
    }
}
