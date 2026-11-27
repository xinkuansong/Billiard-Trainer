import Foundation
import SceneKit
let root=URL(fileURLWithPath:CommandLine.arguments[1])
let config=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("scenario.json"))) as! [String:Any]
let cases=config["cases"] as! [[String:Any]],bins=config["bins"] as! [Int]
func save(_ v:Any,_ name:String)throws {try JSONSerialization.data(withJSONObject:v,options:[.sortedKeys,.prettyPrinted]).write(to:root.appendingPathComponent(name),options:.atomic)}
func group(_ score:Double)->Int? {bins.first{score>=Double($0)-2.5 && score<Double($0)+2.5}}
func directory(_ label:String,_ stage:String)throws->URL {
    let d=root.appendingPathComponent(stage).appendingPathComponent(label);try FileManager.default.createDirectory(at:d,withIntermediateDirectories:true);return d
}
var coarse=[[String:Any]]()
for (i,c) in cases.enumerated() {
    var input=config;input["target"]=c["target"];input["coarseOnly"]=true
    let label=c["label"] as! String,dir=try directory(label,"coarse")
    var result=try autoreleasepool{try scan(output:dir,input:input)};result["label"]=label;result["symmetryKey"]=c["symmetryKey"]
    coarse.append(result)
    if (i+1)%25==0 {try save(coarse,"coarse-summary.json");print("COARSE \(i+1)/\(cases.count)");fflush(stdout)}
}
try save(coarse,"coarse-summary.json")
var refined=[[String:Any]](),done=Set<String>()
func available(_ bin:Int)->Int {Set(refined.filter{group($0["maximum"] as! Double)==bin}.map{$0["symmetryKey"] as! String}).count}
for bin in bins {
    let pool=coarse.filter{let score=$0["maximum"] as! Double;return score>=Double(bin)-5 && score<Double(bin)+2.5}.sorted{
        let a=abs(($0["maximum"] as! Double)-Double(bin)),b=abs(($1["maximum"] as! Double)-Double(bin))
        return a==b ? ($0["label"] as! String)<($1["label"] as! String) : a<b
    }
    for candidate in pool {
        if available(bin)>=12 {break}
        let label=candidate["label"] as! String,key=candidate["symmetryKey"] as! String
        if done.contains(label) {continue}
        // One original orientation per symmetry class; do not pad quotas with mirrors.
        if refined.contains(where:{$0["symmetryKey"] as! String==key}) {continue}
        done.insert(label)
        let c=cases.first{$0["label"] as! String==label}!
        var input=config;input["target"]=c["target"];input["coarseOnly"]=false
        var result=try autoreleasepool{try scan(output:directory(label,"refined"),input:input)}
        result["label"]=label;result["symmetryKey"]=key;refined.append(result)
        try save(refined,"refined-summary.json")
        print("REFINED \(label) max=\(result["maximum"]!) groups=\(bins.map{available($0)})");fflush(stdout)
    }
}
try save(["counts":Dictionary(uniqueKeysWithValues:bins.map{(String($0),available($0))}),"requiredPerBin":10,"allBinsHaveTen":bins.allSatisfy{available($0)>=10}],"native-summary.json")
