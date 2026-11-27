import Foundation
let root=URL(fileURLWithPath:CommandLine.arguments[1])
let inputs=try JSONDecoder().decode([SourceRegion].self,from:Data(contentsOf:root.appendingPathComponent("inputs.json")))
let fm=FileManager.default
let results=root.appendingPathComponent("results");try fm.createDirectory(at:results,withIntermediateDirectories:true)
for item in inputs {
 let path=results.appendingPathComponent(item.id+".json")
 if fm.fileExists(atPath:path.path){continue}
 try autoreleasepool {
  var row=try filterRegion(item)
  if CommandLine.arguments.contains("--verify-unpruned") {
   let plain=try filterRegion(item,prune:false)
   precondition(abs((plain["maximumSampled"] as! Double)-(row["maximumSampled"] as! Double))<1e-9)
   row["unprunedSeconds"]=plain["seconds"];row["unprunedVerified"]=true
  }
  try JSONSerialization.data(withJSONObject:row,options:[.sortedKeys]).write(to:path,options:.atomic)
  print("FINISH \(item.id) \(row["maximumSampled"]!) \(row["seconds"]!) seconds");fflush(stdout)
 }
}
