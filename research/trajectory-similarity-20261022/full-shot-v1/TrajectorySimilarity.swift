// Standalone research reference, deliberately outside the app target.
import Foundation
struct TrajectorySimilarity {
    typealias Point = SIMD2<Double>
    enum Failure: Error { case invalidInput, invalidAnchor }
    struct Distances {
        let frechetCM: Double
        let meanDTWCM: Double
        let chamferCM: Double
        let matchingLength: Int
    }
    static func distance(_ a: Point, _ b: Point) -> Double { hypot(a.x-b.x,a.y-b.y) }
    static func validate(_ p: [Point]) throws {
        guard !p.isEmpty, p.allSatisfy({$0.x.isFinite && $0.y.isFinite}) else {throw Failure.invalidInput}
    }
    // Inputs already in the same physical centimetre coordinate frame.
    static func compare(_ p: [Point], _ q: [Point]) throws -> Distances {
        try validate(p);try validate(q)
        var previousF = Array(repeating: Double.infinity, count:q.count+1)
        var previousD = previousF
        var previousL = Array(repeating:0,count:q.count+1)
        previousF[0]=0;previousD[0]=0
        var closestQ=Array(repeating:Double.infinity,count:q.count),sumP=0.0
        for a in p {
            var f=Array(repeating:Double.infinity,count:q.count+1)
            var d=f,l=Array(repeating:0,count:q.count+1),closestP=Double.infinity
            for j in q.indices {
                let cost=distance(a,q[j]),k=j+1
                closestP=min(closestP,cost);closestQ[j]=min(closestQ[j],cost)
                f[k]=max(cost,min(previousF[k],previousF[k-1],f[k-1]))
                let candidates=[(previousD[k],previousL[k]),(previousD[k-1],previousL[k-1]),(d[k-1],l[k-1])]
                let best=candidates.min { a,b in a.0 == b.0 ? a.1 < b.1 : a.0 < b.0 }!
                d[k]=best.0+cost;l[k]=best.1+1
            }
            previousF=f;previousD=d;previousL=l;sumP+=closestP
        }
        return Distances(frechetCM:previousF.last!,meanDTWCM:previousD.last!/Double(previousL.last!),chamferCM:0.5*(sumP/Double(p.count)+closestQ.reduce(0,+)/Double(q.count)),matchingLength:previousL.last!)
    }
    // Keep endpoints and mandatory event vertices; the returned count may exceed budget.
    static func resample(_ input:[Point],budget:Int=512,mandatory:Set<Int>=[]) throws -> [Point] {
        try validate(input)
        guard budget>=2 else {throw Failure.invalidInput}
        guard mandatory.allSatisfy({input.indices.contains($0)}) else {throw Failure.invalidAnchor}
        var lengths=[0.0]
        for i in 1..<input.count {lengths.append(lengths.last!+distance(input[i-1],input[i]))}
        let total=lengths.last!
        if total==0 {return [input[0]]}
        let locations=Set((0..<budget).map{total*Double($0)/Double(budget-1)}+mandatory.map{lengths[$0]}).sorted()
        var index=0,result:[Point]=[]
        for s in locations {
            while index+1<input.count && lengths[index+1]<=s {index+=1}
            if index==input.count-1 {result.append(input[index]);continue}
            let u=(s-lengths[index])/(lengths[index+1]-lengths[index])
            result.append(input[index]+(input[index+1]-input[index])*u)
        }
        return result
    }
    // Exploratory scale, not a validated training grade or probability.
    static func score(distanceCM:Double,halfScoreDistanceCM:Double) throws -> Double {
        guard distanceCM.isFinite,distanceCM>=0,halfScoreDistanceCM.isFinite,halfScoreDistanceCM>0 else {throw Failure.invalidInput}
        return 100*exp(-log(2)*distanceCM/halfScoreDistanceCM)
    }
}
