import Foundation
// JSON adapter: preserve the production Point's Float coordinate precision.
enum SeparationTrajectory {
 struct Point: Decodable { struct Position:Decodable {let x:Float;let z:Float};let position:Position }
}
struct Row:Decodable {let comboIndex:Int;let points:[SeparationTrajectory.Point]}
let input=URL(fileURLWithPath:CommandLine.arguments[1])
let variants=try JSONDecoder().decode([String:[Row]].self,from:Data(contentsOf:input))
var output=[String:Any]()
for name in variants.keys.sorted() {
 let rows=variants[name]!
 let paths=try rows.map {try SeparationArcRMSMetric.sample($0.points.map { SIMD2(Double($0.position.x)*100,Double($0.position.z)*100) })}
 var pairs=[[String:Any]](); var maximumAPIError=0.0,maximumAsymmetry=0.0
 for i in 0..<rows.count {
  let selfD=try SeparationArcRMSMetric.distance(paths[i],paths[i]);precondition(selfD==0)
  for j in (i+1)..<rows.count {
   let d=try SeparationArcRMSMetric.distance(paths[i],paths[j])
   let score=SeparationTrajectoryScore(rmsDistanceCM:d,targetSampleCount:paths[i].cells.count,actualSampleCount:paths[j].cells.count).value
   if (i*rows.count+j)%97 == 0 {
    let api=try SeparationTrajectoryScore.evaluate(target:rows[i].points,actual:rows[j].points)!
    maximumAPIError=max(maximumAPIError,abs(api.value-score))
    let reverse=try SeparationArcRMSMetric.distance(paths[j],paths[i]);maximumAsymmetry=max(maximumAsymmetry,abs(reverse-d))
   }
   pairs.append(["a":rows[i].comboIndex,"b":rows[j].comboIndex,"score":score,"distanceCM":d])
  }
 }
 precondition(maximumAPIError<1e-10 && maximumAsymmetry<1e-8)
 output[name]=["pairs":pairs,"maxAPIError":maximumAPIError,"maxAsymmetryCM":maximumAsymmetry,"arcCellCounts":paths.map{$0.cells.count}]
 print("\(name): \(pairs.count) pairs; API error \(maximumAPIError)")
}
output["algorithm"]=SeparationTrajectoryScore.algorithm
try JSONSerialization.data(withJSONObject:output,options:[.sortedKeys]).write(to:URL(fileURLWithPath:CommandLine.arguments[2]))
