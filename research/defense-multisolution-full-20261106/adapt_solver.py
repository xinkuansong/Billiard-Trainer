from pathlib import Path
HERE=Path(__file__).resolve().parent;OLD=HERE.parent/'defense-85-validation-20261106'
s=(OLD/'OwnPotential.swift').read_text()
s=s.replace('blocker:SCNVector3','blockers:[SCNVector3]')
s=s.replace('let key="\\(target.x.bitPattern):\\(target.z.bitPattern):\\(blocker.x.bitPattern):\\(blocker.z.bitPattern)"','let key="\\(target.x.bitPattern):\\(target.z.bitPattern):"+blockers.map{"\\($0.x.bitPattern):\\($0.z.bitPattern)"}.joined(separator:"/")')
s=s.replace('        let x=Double(blocker.x)-Double(target.x),z=Double(blocker.z)-Double(target.z),distance=hypot(x,z)\n','')
s=s.replace('let fragments=distance>diameter ? ownSubtractCone([left,right],direction:atan2(z,x),half:asin(min(1,diameter/distance))):[]','''var fragments=[[left,right]]
                for blocker in blockers {
                    let x=Double(blocker.x)-Double(target.x),z=Double(blocker.z)-Double(target.z),distance=hypot(x,z)
                    fragments = distance>diameter ? fragments.flatMap{ownSubtractCone($0,direction:atan2(z,x),half:asin(min(1,diameter/distance)))}:[]
                }''')
(HERE/'OwnPotential.swift').write_text(s)
s=(OLD/'DefenseRegionSolver.swift').read_text()
s=s.replace('    let cue=vec(q.cue),own=vec(q.balls.first{$0.number==8}!.position),enemy=vec(q.balls.first{$0.number==9}!.position)','''    let ownKey="_\\(q.ownBallNumber)",enemyKey="_\\(q.opponentBallNumber)"
    let fixedKeys=q.keys.filter{$0 != ownKey}
    let cue=vec(q.cue),own=vec(q.balls.first{$0.number==q.ownBallNumber}!.position),enemy=vec(q.balls.first{$0.number==q.opponentBallNumber}!.position)
    let fixedPositions=Dictionary(uniqueKeysWithValues:q.balls.filter{$0.number != q.ownBallNumber}.map{("_\\($0.number)",vec($0.position))})
    let staticBlockers=fixedKeys.filter{$0 != enemyKey}.map{fixedPositions[$0]!}
    let ownBlockers=fixedKeys.map{fixedPositions[$0]!}''')
s=s.replace('"_8"','ownKey').replace('"_9"','enemyKey')
s=s.replace('blocker:enemy','blockers:ownBlockers')
s=s.replace('blockers:[],windows:windows','blockers:staticBlockers,windows:windows,opponent:q.opponentBallNumber')
s=s.replace('blockers:[p.finalPositions[ownKey]!],windows:windows','blockers:staticBlockers+[p.finalPositions[ownKey]!],windows:windows,opponent:q.opponentBallNumber')
s=s.replace('blockers:[pp.finalPositions[ownKey]!],windows:windows','blockers:staticBlockers+[pp.finalPositions[ownKey]!],windows:windows,opponent:q.opponentBallNumber')
s=s.replace('return a==enemyKey || b==enemyKey','return fixedKeys.contains(a) || fixedKeys.contains(b)')
s=s.replace('for (i,k) in [cueKey,ownKey,enemyKey].enumerated()', 'for (i,k) in ([cueKey]+q.keys).enumerated()').replace('[cueKey,ownKey,enemyKey].dropFirst(i+1)', '([cueKey]+q.keys).dropFirst(i+1)')
s=s.replace('guard let e=p.finalPositions[enemyKey],defenseDistance(e,enemy)<1e-6 else{return "opponent-moved"}', '''for key in fixedKeys {guard let e=p.finalPositions[key],defenseDistance(e,fixedPositions[key]!)<1e-6 else{return "fixed-ball-moved"}}
        if p.events.contains(where:{if case .ballCushion=$0.kind{return !DefenseReferenceRoute.isMainCushion($0.cushionIndex)};return false}) {return "pocket-jaw-contact"}
        var ownHitRail=false,firstContact=false
        for event in p.events {
            if case let .ballCushion(b)=event.kind,b==ownKey,firstContact {ownHitRail=true}
            if case .ballBall=event.kind {if ownHitRail{return "own-rail-cue-recontact"};firstContact=true}
        }''')
# Retain candidates at 80 only; no 75 fallback enters the new bank.
s=s.replace('total>=75','total>=80').replace('final-below-75','final-below-80').replace('e.score!>=75','e.score!>=80').replace('score>=75','score>=80').replace('stableAt($0,75)','stableAt($0,80)').replace('[75.0,80,85]','[80.0,85]')
# Physical diversity: topology or a substantial terminal-state difference, not grid-boundary artifacts.
anchor='    // Expand only while the primary'
pos=s.index(anchor)
s=s[:pos]+'''    func topology(_ c:DefenseRegionCandidate)->[String] {c.prediction.events.map {e in
        switch e.kind {
        case let .ballBall(a,b):return "B:"+[a,b].sorted().joined(separator:",")
        case let .ballCushion(b):return "C:\\(b):\\(e.cushionIndex ?? -1)"
        case let .pocket(b,k):return "P:\\(b):\\(k)"
        }
    }}
    func different(_ a:DefenseRegionCandidate,_ b:DefenseRegionCandidate)->Bool {
        topology(a) != topology(b) || defenseDistance(a.prediction.finalPositions[cueKey]!,b.prediction.finalPositions[cueKey]!)>=0.08 || defenseDistance(a.prediction.finalPositions[ownKey]!,b.prediction.finalPositions[ownKey]!)>=0.10
    }
    func diverse(_ pool:[DefenseRegionCandidate])->[DefenseRegionCandidate] {
        var chosen=[DefenseRegionCandidate]()
        for c in pool.sorted(by:qualityLess) where chosen.allSatisfy({different(c,$0)}) {
            chosen.append(c);if chosen.count==6 {break}
        };return chosen
    }
'''+s[pos:]
s=s.replace('let stable=dedup.values.filter{stableAt($0,80)}.count','let stable=diverse(dedup.values.filter{stableAt($0,80)}).count').replace('if stable>0 {break}','if stable>=2 {break}')
s=s.replace('// Expand only while the primary 80-point goal lacks a four-probe solution.','// Expand only while fewer than two distinct four-probe 80-point solutions exist.')
s=s.replace('var selected=[DefenseRegionCandidate](),thresholdResults=[[String:Any]]()','let selected=diverse(Array(eligible));var thresholdResults=[[String:Any]]()')
start=s.index('            // One simple representative per pathway/threshold')
end=s.index('        }\n        thresholdResults',start)
s=s[:start]+s[end:]
# A bounded shortlist expands when the first candidates collapse to one route.
s=s.replace('group.sorted(by:qualityLess).prefix(12)','group.sorted(by:qualityLess).prefix(24)')
s=s.replace('"questionID":q.id,','"questionID":q.id,"ownBallNumber":q.ownBallNumber,"opponentBallNumber":q.opponentBallNumber,"admitted":records.count>=2,')
(HERE/'DefenseRegionSolver.swift').write_text(s)
print('Generalized own/opponent/static roles; preserved 80 and four-probe rule; two diverse routes required')
