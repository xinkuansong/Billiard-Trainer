import Foundation
struct Fixture:Decodable {let a:[[Double]];let b:[[Double]];let expected:[Double]}
let fixtures=try JSONDecoder().decode([Fixture].self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))
var maxError=0.0
for fixture in fixtures {
    let result=try TrajectorySimilarity.compare(fixture.a.map{SIMD2($0[0],$0[1])},fixture.b.map{SIMD2($0[0],$0[1])})
    let values=[result.frechetCM,result.meanDTWCM,result.chamferCM]
    for (a,b) in zip(values,fixture.expected) {maxError=max(maxError,abs(a-b));precondition(abs(a-b)<1e-8)}
}
let corner=[SIMD2<Double>(0,0),SIMD2<Double>(10,0),SIMD2<Double>(10,20)]
let sampled=try TrajectorySimilarity.resample(corner,mandatory:[1])
precondition(sampled.contains(corner[1]) && sampled.first==corner.first && sampled.last==corner.last)
let repeated=try TrajectorySimilarity.resample([.zero,.zero,SIMD2(10,0)],mandatory:[1])
precondition(repeated.allSatisfy{$0.x.isFinite && $0.y.isFinite})
print("{\"passed\":true,\"pairCount\":\(fixtures.count),\"maxErrorCM\":\(maxError),\"resamplingCornerAndDuplicates\":true}")
