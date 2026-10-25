import Foundation

typealias Pt = SIMD2<Double>
struct Cell { let mid: Pt; let end: Pt; let length: Double }
struct Line { let start: Pt; let cells: [Cell]; let length: Double }
func sample(_ p: [Pt], step: Double = 1) -> Line {
    var ls = [0.0]
    for i in 1..<p.count { ls.append(ls.last! + hypot(p[i].x-p[i-1].x,p[i].y-p[i-1].y)) }
    let total=ls.last!
    if total == 0 { return Line(start:p[0],cells:[],length:0) }
    var cursor=0
    func at(_ s: Double) -> Pt {
        while cursor+1<p.count && ls[cursor+1]<=s { cursor += 1 }
        if cursor==p.count-1 { return p.last! }
        return p[cursor]+(p[cursor+1]-p[cursor])*((s-ls[cursor])/(ls[cursor+1]-ls[cursor]))
    }
    var cells=[Cell]()
    for i in 0..<Int(ceil(total/step)) {
        let lo=Double(i)*step, hi=min(lo+step,total)
        cells.append(Cell(mid:at((lo+hi)/2),end:at(hi),length:hi-lo))
    }
    return Line(start:p[0],cells:cells,length:total)
}
// Same midpoint-grid recurrence as the research implementation. p=2 uses
// squared coordinate differences; it does not compute a square root per cell.
func candidate(_ a:Line,_ b:Line,p:Double) -> Double {
    if a.length+b.length==0 { return 100*exp2(-hypot(a.start.x-b.start.x,a.start.y-b.start.y)/20) }
    func cost(_ x:Pt,_ y:Pt)->Double {
        let dx=x.x-y.x,dy=x.y-y.y
        if p==2 { return dx*dx+dy*dy }
        let d=hypot(dx,dy)
        return p==1 ? d : pow(d,p)
    }
    var prev=Array(repeating:0.0,count:b.cells.count+1),cur=prev
    for j in b.cells.indices { prev[j+1]=prev[j]+b.cells[j].length*cost(a.start,b.cells[j].mid) }
    for x in a.cells {
        cur[0]=prev[0]+x.length*cost(x.mid,b.start)
        for j in b.cells.indices {
            let y=b.cells[j]
            cur[j+1]=min(prev[j+1]+x.length*cost(x.mid,y.end),
                         cur[j]+y.length*cost(x.end,y.mid),
                         prev[j]+(x.length+y.length)*cost(x.mid,y.mid))
        }
        swap(&prev,&cur)
    }
    return 100*exp2(-pow(prev.last!/(a.length+b.length),1/p)/20)
}
@main struct Bench {
 static func main() throws {
    let root=URL(fileURLWithPath:CommandLine.arguments[1])
    func json(_ path:String)throws->[String:Any] { try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent(path))) as! [String:Any] }
    let native=try json("output/two-ball-b42-dedup75-20261024/native-result.json")
    let ref=try json("research/trajectory-similarity-20261024-unified-score/p2-results.json")
    var raw=[Int:[Pt]](),anchors=[Int:Set<Int>]()
    for row in native["rows"] as! [[String:Any]] {
        let id=row["comboIndex"] as! Int, line=row["comparisonLine"] as! [[String:Any]]
        raw[id]=line.map { q in let v=q["position"] as! [String:Double]; return Pt(v["x"]!*100,v["z"]!*100) }
        anchors[id]=Set(line.indices.filter { line[$0]["isEvent"] as? Bool == true })
    }
    let ids=raw.keys.sorted()
    func now()->Double { Double(DispatchTime.now().uptimeNanoseconds)/1e9 }
    let startPrep=now()
    let old=try Dictionary(uniqueKeysWithValues:ids.map { id in
        let nativePoints=raw[id]!.map { Pt(Double(Float($0.x/100))*100,Double(Float($0.y/100))*100) }
        return (id,try SeparationTrajectoryMetric.resample(nativePoints,mandatory:anchors[id]!))
    })
    let oldPrep=now()-startPrep, newStart=now()
    let lines=Dictionary(uniqueKeysWithValues:ids.map { ($0,sample(raw[$0]!)) })
    let newPrep=now()-newStart
    func oldScore(_ a:Int,_ b:Int)throws->Double {
        let d=try SeparationTrajectoryMetric.compare(old[a]!,old[b]!)
        return 100*exp2(-(0.7*d.meanDTWCM + 0.3*d.frechetCM)/20)
    }
    var maxError=0.0,totalNew=0.0,newTimes=[Double]()
    for pair in ref["allPairs"] as! [[String:Any]] {
        let a=pair["a"] as! Int,b=pair["b"] as! Int,t=now()
        let value=candidate(lines[a]!,lines[b]!,p:2)
        newTimes.append((now()-t)*1000);totalNew += value
        maxError=max(maxError,abs(value-(pair["p2"] as! Double)))
    }
    guard maxError<1e-8 else { throw NSError(domain:"p2-score-mismatch",code:1,userInfo:[NSLocalizedDescriptionKey:"Maximum error: \(maxError)"]) }
    print("p2 all-pairs verified, max error \(maxError)")
    var oldTimes=[Double](),totalOld=0.0,maxOldError=0.0
    for pair in native["pairs"] as! [[String:Any]] {
        let a=pair["a"] as! Int,b=pair["b"] as! Int,t=now()
        let value=try oldScore(a,b)
        oldTimes.append((now()-t)*1000);totalOld += value
        maxOldError=max(maxOldError,abs(value-(pair["score"] as! Double)))
    }
    guard maxOldError<0.0001 else { throw NSError(domain:"old-score-mismatch",code:1,userInfo:[NSLocalizedDescriptionKey:"Maximum error: \(maxOldError)"]) }
    func stats(_ v:[Double])->[String:Double] {
        let s=v.sorted()
        return ["medianMS":s[s.count/2],"p95MS":s[Int(Double(s.count-1)*0.95)],"maxMS":s.last!,"totalSeconds":s.reduce(0,+)/1000]
    }
    var focus=[[String:Any]]()
    for (a,b) in [(237,235),(398,287),(493,507)] {
        var timing=[String:Any]()
        for method in ["old","p1","p15","p2"] {
            var times=[Double](),sum=0.0
            for _ in 0..<55 {
                let t=now()
                let v=try method=="old" ? oldScore(a,b) : candidate(lines[a]!,lines[b]!,p:method=="p1" ? 1 : method=="p15" ? 1.5 : 2)
                times.append((now()-t)*1000);sum += v
            }
            timing[method]=stats(Array(times.dropFirst(5)))
            timing[method+"Score"]=sum/55
        }
        focus.append(["a":a,"b":b,"oldPoints":[old[a]!.count,old[b]!.count],"newCells":[lines[a]!.cells.count,lines[b]!.cells.count],"timings":timing])
    }
    let result:[String:Any]=["platform":"Apple M5 Pro / macOS / Swift -O, single process", "scope":"93 real trajectories, 4278 pairs, cached resampling; scoring time only; not an iPhone benchmark", "stepCM":1,"oldAllPairs":stats(oldTimes),"p2AllPairs":stats(newTimes),"resampling93MS":["old":oldPrep*1000,"new":newPrep*1000],"maxP2ScoreError":maxError,"maxOldScoreError":maxOldError,"checksum":[totalNew,totalOld],"focus":focus]
    let data=try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:root.appendingPathComponent("research/trajectory-similarity-20261024-unified-score/benchmark-results.json"))
    print(String(data:data,encoding:.utf8)!)
 }
}
