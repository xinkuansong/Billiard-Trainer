from pathlib import Path
p=Path(__file__).with_name('DefenseRegionSolver.swift');s=p.read_text()
s=s.replace('var seeds=[String:(Double,DefenseRegionStroke)]()','var seeds=[String:(Double,DefenseRegionStroke)]()\n    var blockingSeeds=[String:(Double,DefenseRegionStroke)]()')
start=s.index('        guard let block=map.block(at:stop) else')
end=s.index('        let potential=ownEvaluator',start)
s=s[:start]+'''        // Both pathways share a candidate pool. Never reject before considering moved 8.
        let block=map.block(at:stop) ?? -1
        let base=try DefenseEffect.regionState(cue:stop,target:enemy,blockers:[],windows:windows)
        let effect=try DefenseEffect.regionState(cue:stop,target:enemy,blockers:[p.finalPositions["_8"]!],windows:windows)
        guard let total=effect.score else {throw NSError(domain:"missing-terminal-score",code:1)}
        // Seed 8-to-cue/9-line proximity separately from intrinsic difficult regions.
        let o=p.finalPositions["_8"]!,vx=Double(enemy.x-stop.x),vz=Double(enemy.z-stop.z)
        let t=max(0,min(1,(Double(o.x-stop.x)*vx+Double(o.z-stop.z)*vz)/(vx*vx+vz*vz)))
        let lineGap=hypot(Double(o.x-stop.x)-t*vx,Double(o.z-stop.z)-t*vz)-2*r
        let sk="\\(s.cut):\\(s.side):\\(s.spinX):\\(s.spinY)"
        for (suffix,objective) in [("line",lineGap),("score",-total)] {
            let k=sk+suffix
            if blockingSeeds[k]==nil || objective<blockingSeeds[k]!.0 {blockingSeeds[k]=(objective,s)}
        }
        guard total>=70 else {fail("final-below-70");return}
        let margin=block>=0 ? -Double(map.blocks[block].region.signedDistanceMeters(fromScene:stop,surfaceY:surface)) : 0
''' +s[end:]
s=s.replace('let key=signature(p,block)','let key=signature(p,block)+"|band:\\(Int(total/10))|block:\\(effect.fullDirectBlock || effect.potContactsBlocked==true)"')
s=s.replace('let good=e.score!>=90 && b.score!>=90 && map.block(at:end) != nil','let good=e.score!>=70')
s=s.replace('rec["score"]=e.score!;rec["baseScore"]=b.score!;rec["defensePasses"]=good','rec["score"]=e.score!;rec["baseScore"]=b.score!;rec["defensePasses"]=good\n                rec["effect"]=try defenseEncode(e);rec["baseEffect"]=try defenseEncode(b)')
a=s.index('    // Parameters are means, never output quotas.')
b=s.index('    let spinTiers',a)
s=s[:a]+'''    func stableAt(_ c:DefenseRegionCandidate,_ threshold:Double)->Bool {
        c.effect.score!>=threshold && c.own.preserves(ownBefore) &&
        probeCache[c.stroke.key]?.filter{($0["score"] as? Double ?? -1)>=threshold && ($0["ownPreserved"] as? Bool ?? false)}.count==4
    }
    func pathway(_ c:DefenseRegionCandidate,_ threshold:Double)->String {
        c.base.score!>=threshold ? "intrinsic" : "blocking-added"
    }
    // Expand only while the highest diagnostic threshold lacks a robust solution.
    // All thresholds are evaluated on exactly the same final parameter pool.
''' +s[b:]
s=s.replace('let starts=seeds.values.sorted {a,b in a.0 == b.0 ? a.1.key<b.1.key:a.0<b.0}.prefix(24).map{$0.1}', '''let regionStarts=seeds.values.sorted {a,b in a.0 == b.0 ? a.1.key<b.1.key:a.0<b.0}.prefix(24).map{$0.1}
        let blockStarts=blockingSeeds.values.sorted {a,b in a.0 == b.0 ? a.1.key<b.1.key:a.0<b.0}.prefix(24).map{$0.1}
        let starts=regionStarts+blockStarts''')
a=s.index('        var shortlist=Array(eligible.sorted')
b=s.index('        for c in shortlist',a)
s=s[:a]+'''        var shortlist=[DefenseRegionCandidate]()
        for threshold in [70.0,80,90] {for path in ["intrinsic","blocking-added"] {
            let group=eligible.filter{$0.effect.score!>=threshold && pathway($0,threshold)==path}
            let easy=group.sorted(by:qualityLess).prefix(12)
            let strong=group.sorted {a,b in
                if a.own.bestClearDegrees != b.own.bestClearDegrees {return (a.own.bestClearDegrees ?? 0)>(b.own.bestClearDegrees ?? 0)}
                return qualityLess(a,b)
            }.prefix(12)
            for c in Array(easy)+Array(strong) where !shortlist.contains(where:{$0.stroke.key==c.stroke.key}) {shortlist.append(c)}
        }}
''' +s[b:]
s=s.replace('let stable=dedup.values.filter{c in c.own.preserves(ownBefore) && probeCache[c.stroke.key]?.filter{$0["passes"] as! Bool}.count==4}.count','let stable=dedup.values.filter{stableAt($0,90)}.count')
a=s.index('    let eligible=dedup.values.filter {c in')
b=s.index('    let summaries=',a)
s=s[:a]+'''    let eligible=dedup.values.filter{stableAt($0,70)}
    var selected=[DefenseRegionCandidate](),thresholdResults=[[String:Any]]()
    for threshold in [70.0,80,90] {
        let qualified=dedup.values.filter{$0.effect.score!>=threshold}
        let stable=qualified.filter{stableAt($0,threshold)}
        var paths=[String:Int]()
        for path in ["intrinsic","blocking-added"] {
            let group=stable.filter{pathway($0,threshold)==path}
            paths[path]=group.count
            // Show lowest effort and largest retained own-window tradeoffs, no quota of spin/cushions.
            var choices=Array(group.sorted(by:qualityLess).prefix(1))
            if let best=group.max(by:{($0.own.bestClearDegrees ?? 0)<($1.own.bestClearDegrees ?? 0)}) {choices.append(best)}
            for c in choices where !selected.contains(where:{$0.stroke.key==c.stroke.key}) {selected.append(c)}
        }
        thresholdResults.append(["threshold":threshold,"nominal":qualified.count,"preservesOwn":qualified.filter{$0.own.preserves(ownBefore)}.count,"robust":stable.count,"paths":paths])
    }
''' +s[b:]
s=s.replace('"defenseScore":c.effect.score!,"own":','"defenseScore":c.effect.score!,"baseScore":c.base.score!,"effect":try! defenseEncode(c.effect),"baseEffect":try! defenseEncode(c.base),"stableThresholds":[70.0,80,90].filter{stableAt(c,$0)},"own":')
s=s.replace('map.block(at:stop)==c.block','(map.block(at:stop) ?? -1)==c.block').replace('score>=90','score>=70')
s=s.replace('"paretoCount":pareto.count,','"thresholdResults":thresholdResults,')
s=s.replace('"id":i+1,"block":c.block,','"id":i+1,"stableThresholds":[70.0,80,90].filter{stableAt(c,$0)},"block":c.block,')
p.write_text(s)

# Separate the units of line clearance and terminal score in seed ranking.
s=p.read_text()
s=s.replace('let blockStarts=blockingSeeds.values.sorted {a,b in a.0 == b.0 ? a.1.key<b.1.key:a.0<b.0}.prefix(24).map{$0.1}','// Distances and scores have different units; rank the two seed objectives separately.\n        let blockStarts=["line","score"].flatMap { kind in\n            blockingSeeds.filter{$0.key.hasSuffix(kind)}.values.sorted {a,b in a.0 == b.0 ? a.1.key<b.1.key:a.0<b.0}.prefix(12).map{$0.1}\n        }')
p.write_text(s)
